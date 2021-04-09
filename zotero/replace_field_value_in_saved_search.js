// Change a specific field in a saved search

var fieldName = "language";
var newValue = "it";
var searchKey = "XXXXXXX" // Get the key from the web API

var fieldID = Zotero.ItemFields.getID(fieldName);
var s = new Zotero.Search();
s.libraryID = Zotero.Libraries.userLibraryID;
s.addCondition('savedSearch', 'is', searchKey);
var ids = await s.search();
if (!ids.length) {
    return "No items found";
}
await Zotero.DB.executeTransaction(async function () {
    for (let id of ids) {
        let item = await Zotero.Items.getAsync(id);
        let mappedFieldID = Zotero.ItemFields.getFieldIDFromTypeAndBase(item.itemTypeID, fieldName);
        item.setField(mappedFieldID ? mappedFieldID : fieldID, newValue);
        await item.save();
    }
});
return ids.length + " item(s) updated";
