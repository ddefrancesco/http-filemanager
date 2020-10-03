import ballerina/mime;
import ballerinax/java.jdbc;
import ballerina/time;
import ballerina/io;




public type Payload object {
    public mime:Entity? bodyPart = ();
    public string|xml|json printableContent = "";
    public byte[] content = []; 
    public Payload? parent = ();
        
};

public type PayloadRecord record {
    int id;
    string printableContent;
    time:Time insertedTime;
};



function handleDataContent(mime:Entity bodyPart) returns @tainted string|error {
    mime:MediaType mediaType = check mime:getMediaType(bodyPart.getContentType());
    string baseType = mediaType.getBaseType();
    byte[] data = check bodyPart.getByteArray();
    string base64 = data.toBase64();
    return base64;
}

function handleUpdate(jdbc:UpdateResult|jdbc:Error returned, string message) {
    if (returned is jdbc:UpdateResult) {
        io:println(message, " status: ", returned.updatedRowCount);
    } else {
        io:println(message, " failed: ", <string>returned.detail()?.message);
    }
}