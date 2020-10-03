import ballerina/mime;
import ballerinax/java.jdbc;
import ballerina/time;
import ballerina/io;
import ballerina/log;




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

function getContentDispositionForFormData(string partName)
                                    returns (mime:ContentDisposition) {
    mime:ContentDisposition contentDisposition = new;
    contentDisposition.name = partName;
    contentDisposition.disposition = "form-data";
    return contentDisposition;
}

function close(io:ReadableByteChannel|io:WritableByteChannel ch) {
    abstract object {
        public function close() returns error?;
    } channelResult = ch;
    var cr = channelResult.close();
    if (cr is error) {
        log:printError("Error occurred while closing the channel: ", cr);
    }
}

function writeToFile(string fullPath, byte[] payload) returns @tainted error?{
        
        io:WritableByteChannel writableByteChannel = check io:openWritableFile(fullPath);
        int i = 0;
        while (i < payload.length()) {
            var result2 = writableByteChannel.write(payload, i);
            if (result2 is error) {
                return result2;
            } else {
                i = i + result2;
            }
        }
        
        close(writableByteChannel);
    return;
}

