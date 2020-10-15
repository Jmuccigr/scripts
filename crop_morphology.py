#!/usr/bin/env python3
'''
Crop an image to just the portions containing text.

Usage:

    ./crop_morphology.py path/to/image.jpg

This will place the cropped image in path/to/image.crop.png.

For details on the methodology, see
http://www.danvk.org/2015/01/07/finding-blocks-of-text-in-an-image-using-python-opencv-and-numpy.html

Script created by Dan Vanderkam (https://github.com/danvk)
Adapted to Python 3 by Lui Pillmann (https://github.com/luipillmann)
Subsequently adapted by Fábio Franco Uechi.
Further adapted by John Muccigrosso.
'''

import glob
import os
import random
import sys
import random
import math
import json
from collections import defaultdict

import cv2
from PIL import Image, ImageDraw
import numpy as np
from scipy.ndimage.filters import rank_filter
from matplotlib import pyplot as plt


def dilate(ary, N, iterations):
    """Dilate using an NxN '+' sign shape. ary is np.uint8."""

    kernel = np.zeros((N,N), dtype=np.uint8)
    kernel[(N-1)//2,:] = 1  # Bug solved with // (integer division)

    dilated_image = cv2.dilate(ary / 255, kernel, iterations=iterations)

    kernel = np.zeros((N,N), dtype=np.uint8)
    kernel[:,(N-1)//2] = 1  # Bug solved with // (integer division)
    dilated_image = cv2.dilate(dilated_image, kernel, iterations=iterations)
    return dilated_image


def props_for_contours(contours, ary):
    """Calculate bounding box & the number of set pixels for each contour."""
    c_info = []
    for c in contours:
        x,y,w,h = cv2.boundingRect(c)
        c_im = np.zeros(ary.shape)
        cv2.drawContours(c_im, [c], 0, 255, -1)
        c_info.append({
            'x1': x,
            'y1': y,
            'x2': x + w - 1,
            'y2': y + h - 1,
            'sum': np.sum(ary * (c_im > 0))/255
        })
    return c_info


def union_crops(crop1, crop2):
    """Union two (x1, y1, x2, y2) rects."""
    x11, y11, x21, y21 = crop1
    x12, y12, x22, y22 = crop2
    return min(x11, x12), min(y11, y12), max(x21, x22), max(y21, y22)


def intersect_crops(crop1, crop2):
    x11, y11, x21, y21 = crop1
    x12, y12, x22, y22 = crop2
    return max(x11, x12), max(y11, y12), min(x21, x22), min(y21, y22)


def crop_area(crop):
    x1, y1, x2, y2 = crop
    return max(0, x2 - x1) * max(0, y2 - y1)


def find_border_components(contours, ary):
    borders = []
    area = ary.shape[0] * ary.shape[1]
    for i, c in enumerate(contours):
        x,y,w,h = cv2.boundingRect(c)
        if w * h > 0.5 * area:
            borders.append((i, x, y, x + w - 1, y + h - 1))
    return borders


def angle_from_right(deg):
    return min(deg % 90, 90 - (deg % 90))


def remove_border(contour, ary):
    """Remove everything outside a border contour."""
    # Use a rotated rectangle (should be a good approximation of a border).
    # If it's far from a right angle, it's probably two sides of a border and
    # we should use the bounding box instead.
    c_im = np.zeros(ary.shape)
    r = cv2.minAreaRect(contour)
    degs = r[2]
    if angle_from_right(degs) <= 10.0:
        box = cv2.boxPoints(r)
        box = np.int0(box)
        cv2.drawContours(c_im, [box], 0, 255, -1)
        cv2.drawContours(c_im, [box], 0, 0, 4)
    else:
        x1, y1, x2, y2 = cv2.boundingRect(contour)
        cv2.rectangle(c_im, (x1, y1), (x2, y2), 255, -1)
        cv2.rectangle(c_im, (x1, y1), (x2, y2), 0, 4)

    return np.minimum(c_im, ary)


def find_components(edges, max_components=7):
    """Dilate the image until there are just a few connected components.

    Returns contours for these components."""
    # Perform increasingly aggressive dilation until there are just a few
    # connected components.
    count = max_components + 1
    #dilation = 5 - JM: Doesn't do anything
    n = 0
    while count > max_components:
        n += 1
        dilated_image = dilate(edges, N=3, iterations=n)
        dilated_image = np.uint8(dilated_image)
        contours,hierachy=cv2.findContours(dilated_image,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
        count = len(contours)
    return contours


def find_optimal_components_subset(contours, edges):
    """
    Find a crop which strikes a good balance of coverage/compactness.

    Returns an (x1, y1, x2, y2) tuple.
    """
    c_info = props_for_contours(contours, edges)
    c_info.sort(key=lambda x: -x['sum'])
    h = edges.shape[0]
    w = edges.shape[1]
    area = h * w
    # Remove strips at top or bottom as likely scanning artifacts
    too_close = 0.05
    for i, c in enumerate(c_info):
        if ( c['y2'] <  too_close * h   or
            c['x2'] <  too_close * w   or
            c['y1'] >  h - (too_close * h) or
             c['x1'] > w - (too_close * w) ):
            del c_info[i]
    total = np.sum(edges) / 255

    c = c_info[0]
    del c_info[0]
    this_crop = c['x1'], c['y1'], c['x2'], c['y2']
    crop = this_crop
    covered_sum = c['sum']
    counter = 0

    while covered_sum < total:
        changed = False
        recall = 1.0 * covered_sum / total
        prec = 1 - 1.0 * crop_area(crop) / area
        f1 = 2 * (prec * recall / (prec + recall))
        for i, c in enumerate(c_info):
            counter += 1
            this_crop = c['x1'], c['y1'], c['x2'], c['y2']
            new_crop = union_crops(crop, this_crop)
            new_sum = covered_sum + c['sum']
            # Add this crop if it improves f1 score,
            # _or_ it adds a min fraction of the remaining pixels for a maximum crop expansion.
            # _or_ it's a big enough %age of the width of the image to be something
            # ^^^ very ad-hoc! make this smoother
            min_remaining_frac = .25
            wide_enough = .50
            too_close = 0.05
            remaining_frac = c['sum'] / (total - covered_sum)
            if ( remaining_frac > min_remaining_frac ) or (
                    ( this_crop[2] - this_crop[0] ) > wide_enough * w ) :
                crop = new_crop
                covered_sum = new_sum
                del c_info[i]
                changed = True
                break

        if not changed:
            break

    return crop


def pad_crop(crop, contours, edges, border_contour, pad_px=15):
    """Slightly expand the crop to get full contours.

    This will expand to include any contours it currently intersects, but will
    not expand past a border.
    """
    bx1, by1, bx2, by2 = 0, 0, edges.shape[0], edges.shape[1]
    if border_contour is not None and len(border_contour) > 0:
        c = props_for_contours([border_contour], edges)[0]
        bx1, by1, bx2, by2 = c['x1'] + 5, c['y1'] + 5, c['x2'] - 5, c['y2'] - 5

    def crop_in_border(crop):
        x1, y1, x2, y2 = crop
        x1 = max(x1 - pad_px, bx1)
        y1 = max(y1 - pad_px, by1)
        x2 = min(x2 + pad_px, bx2)
        y2 = min(y2 + pad_px, by2)
        return crop

    crop = crop_in_border(crop)

    c_info = props_for_contours(contours, edges)
    changed = False
    for c in c_info:
        this_crop = c['x1'], c['y1'], c['x2'], c['y2']
        this_area = crop_area(this_crop)
        int_area = crop_area(intersect_crops(crop, this_crop))
        new_crop = crop_in_border(union_crops(crop, this_crop))
        if 0 < int_area < this_area and crop != new_crop:
            print('%s -> %s' % (str(crop), str(new_crop)))
            changed = True
            crop = new_crop

    if changed:
        return pad_crop(crop, contours, edges, border_contour, pad_px)
    else:
        return crop


def downscale_image(im, max_dim=2048):
    """Shrink im until its longest dimension is <= max_dim.

    Returns new_image, scale (where scale <= 1).
    """
    b, a = im.shape
    if max(a, b) <= max_dim:
        return 1.0, im

    scale = 1.0 * max_dim / max(a, b)
    new_im = cv2.resize(im, (int(a * scale), int(b * scale)))
    return scale, new_im


def auto_canny(image, sigma=0.33):
	# compute the median of the single channel pixel intensities
	v = np.median(image)
	# apply automatic Canny edge detection using the computed median
	lower = int(max(0, (1.0 - sigma) * v))
	upper = int(min(255, (1.0 + sigma) * v))
	# return the edged image
	return (lower,upper)


def process_image(path, out_path):
    print ('Starting...')
    orig_im = cv2.imread(path)


    im = cv2.cvtColor(orig_im, cv2.COLOR_BGR2GRAY)
    scale, gray = downscale_image(im)
    params = auto_canny (gray)
    edges = cv2.Canny(np.asarray(gray), params[0], params[1])

#   TODO: dilate image _before_ finding a border. This is crazy sensitive!
    contours,hierachy=cv2.findContours(edges,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
    borders = find_border_components(contours, edges)
    borders.sort(key=lambda i_x1_y1_x2_y2: (i_x1_y1_x2_y2[3] - i_x1_y1_x2_y2[1]) * (i_x1_y1_x2_y2[4] - i_x1_y1_x2_y2[2]))
    border_contour = None
    if len(borders):
        border_contour = contours[borders[0][0]]
        edges = remove_border(border_contour, edges)

    edges = 255 * (edges > 0).astype(np.uint8)

#     Remove ~1px borders using a rank filter.
#     Leave horizontal lines - JM
#     maxed_cols = rank_filter(edges, -4, size=(20, 1))
#     debordered = np.minimum(np.minimum(edges, maxed_rows), maxed_cols)
    maxed_rows = rank_filter(edges, -4, size=(1, 20))
    debordered = np.minimum(edges, maxed_rows)
    edges = debordered

    contours = find_components(edges)
    if len(contours) == 0:
        print('%s -> (no text!)' % path)
        return

    crop = find_optimal_components_subset(contours, edges)
    crop = pad_crop(crop, contours, edges, border_contour)
    crop = [int(x / scale) for x in crop]  # upscale to the original image size.

    #draw = ImageDraw.Draw(im)
    #c_info = props_for_contours(contours, edges)
    #for c in c_info:
    #    this_crop = c['x1'], c['y1'], c['x2'], c['y2']
    #    draw.rectangle(this_crop, outline='blue')
    #draw.rectangle(crop, outline='red')
    #im.save(out_path)
    #draw.text((50, 50), path, fill='red')
    #orig_im.save(out_path)
    #im.show()
    img = Image.open(path)
    text_im = img.crop(crop)
    text_im.save(out_path)
    print('%s -> %s' % (path, out_path))


if __name__ == '__main__':
    if len(sys.argv) == 2 and '*' in sys.argv[1]:
        files = glob.glob(sys.argv[1])
        random.shuffle(files)
    else:
        files = sys.argv[1:]

    for path in files:
        out_path = path + ".crop.png"
        #out_path = path.replace('.png', '.crop.png')  # .png as input
        if os.path.exists(out_path):
            print ('\aOutput file already exists. Quitting.')
            continue
        if not os.path.exists(path):
            print ('\aInput file missing. Quitting.')
            continue
        try:
            process_image(path, out_path)
        except Exception as e:
            print('%s %s' % (path, e))
