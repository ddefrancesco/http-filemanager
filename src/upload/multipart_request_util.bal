import ballerina/mime;


function handleDataContent(mime:Entity bodyPart) returns @tainted string|error {
    mime:MediaType mediaType = check mime:getMediaType(bodyPart.getContentType());
    string baseType = mediaType.getBaseType();
    byte[] data = check bodyPart.getByteArray();
    string base64 = data.toBase64();
    return base64;
}