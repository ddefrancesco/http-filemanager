import ballerina/mime;

public type Payload object {
    public mime:Entity? bodyPart = ();
    public string|xml|json printableContent = "";
    public byte[] content = []; 
    public Payload? parent = ();
        
};
function handleDataContent(mime:Entity bodyPart) returns @tainted string|error {
    mime:MediaType mediaType = check mime:getMediaType(bodyPart.getContentType());
    string baseType = mediaType.getBaseType();
    byte[] data = check bodyPart.getByteArray();
    string base64 = data.toBase64();
    return base64;
}