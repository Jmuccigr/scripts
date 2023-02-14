var checkFieldName = "fieldname1";
var targetFieldName = "fieldname2";
var searchValue = "Foo";
var replaceValue = "Bar";

var fieldID = Zotero.ItemFields.getID(checkFieldName);

var s = new Zotero.Search;
// Exclude group libraries
var groups = Zotero.Groups.getAll();
for (let group of groups) {
s.addCondition('libraryID', 'isNot', group.libraryID);
}


s.addCondition(checkFieldName, 'is', searchValue);
var ids = s.search();
if (ids) {
	for each(var id in ids) {
		var item = Zotero.Items.get(id);
		var mappedFieldID = Zotero.ItemFields.getFieldIDFromTypeAndBase(item.itemTypeID, targetFieldName);
		item.setField(mappedFieldID ? mappedFieldID : targetFieldName, replaceValue);
		item.save();
	}
	alert(ids.length + " items updated");
}
else {
	alert("No items found");
}
