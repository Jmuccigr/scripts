// Change some text in a specific field
// Only changes first instance in each field

var fieldName = "language";
var oldValue = "English";
var newValue = "en";

var fieldID = Zotero.ItemFields.getID(fieldName);
var s = new Zotero.Search();
s.libraryID = Zotero.Libraries.userLibraryID;
s.addCondition(fieldName, 'contains', oldValue);
var ids = await s.search();
if (!ids.length) {
    return "No items found";
}
await Zotero.DB.executeTransaction(async function () {
    for (let id of ids) {
        let item = await Zotero.Items.getAsync(id);
        let mappedFieldID = Zotero.ItemFields.getFieldIDFromTypeAndBase(item.itemTypeID, fieldName);
		finalValue = item.getField(fieldName).replace(oldValue, newValue);
        item.setField(mappedFieldID ? mappedFieldID : fieldID, finalValue);
        await item.save();
    }
});
return ids.length + " item(s) updated";
