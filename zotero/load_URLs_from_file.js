// Load URLs from a file

var path = '/path/to/file/urls.txt';
var urls = Zotero.File.getContents(path).split('\n').map(url => url);
await Zotero.HTTP.processDocuments(
    urls,
    async function (doc) {
        var translate = new Zotero.Translate.Web();
        translate.setDocument(doc);
        var translators = await translate.getTranslators();
        if (translators.length) {
            translate.setTranslator(translators[0]);
            try {
                await translate.translate();
                return;
            } catch (e) {}
        }
        await ZoteroPane.addItemFromDocument(doc);
    }
)
