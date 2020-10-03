import ballerina/mime;
import ballerinax/java.jdbc;
import ballerina/time;
import ballerina/io;
import ballerina/log;
import ballerina/http;




public type Payload object {
    public mime:Entity? bodyPart = ();
    public string|xml|json printableContent = "";
    public string fileName = "";
    public byte[] content = []; 
    public int httpStatusCode = 0;
    public Payload? parent = ();
    // public function __init(mime:Entity? bodyPart, string|xml|json printableContent, string fileName,byte[] content) {
    //     self.bodyPart = bodyPart;
    //     self.printableContent = printableContent;
    //     self.fileName = fileName;
    //     self.content = content;
    // }
    public function getPrintableContent() returns string|xml|json {
        return self.printableContent;
    }
    public function getHttpStatusCode() returns int {
        return self.httpStatusCode;
    }   

    public function getFileName() returns string {
        return self.fileName;
    }    
 
};

public type PayloadRecord record {
    int id;
    string printableContent;
    string fileName;
    int httpStatusCode;
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

    function handleContent(mime:Entity bodyPart,string fileName) returns @tainted Payload|error?{
    Payload payloadObj = new; 
    
    var mediaType = mime:getMediaType(bodyPart.getContentType());
    log:printInfo(">>>>handle content begin<<<<");
    if (mediaType is mime:MediaType) {
        string baseType = mediaType.getBaseType();
        log:printDebug("baseType "+ baseType);
        if (mime:APPLICATION_XML == baseType || mime:TEXT_XML == baseType ) {

            var payload = bodyPart.getXml();
            if (payload is xml) {
                log:printInfo(payload.toString());
                payloadObj.printableContent=<xml>payload;
                            
                jdbc:Parameter p2 = {sqlType: jdbc:TYPE_VARCHAR, value: payloadObj.printableContent};
                jdbc:Parameter p3 = {
                    sqlType: jdbc:TYPE_TIMESTAMP,
                    value: time:currentTime()
                };
                
                var inserted = testDB ->update("INSERT INTO payload(payload_content, insertedTime) values (?,?)", p2,p3 );
                handleUpdate(inserted,"Inserimento record" );

            } else {
                log:printError(<string>payload.detail().message);
            }
            
        } else if (mime:APPLICATION_JSON == baseType) {

            var payload = bodyPart.getJson();
            if (payload is json) {
                log:printInfo(payload.toJsonString());
                payloadObj.printableContent=<json>payload;
                jdbc:Parameter p2 = {sqlType: jdbc:TYPE_VARCHAR, value: payloadObj.printableContent};
                jdbc:Parameter p3 = {
                    sqlType: jdbc:TYPE_TIMESTAMP,
                    value: time:currentTime()
                };
                
                payloadObj.fileName = fileName;
                payloadObj.printableContent = "file "+fileName+" salvato";
                payloadObj.httpStatusCode = http:STATUS_OK;
        
                var inserted = testDB ->update("INSERT INTO payload(payload_content, insertedTime) values (?,?)", p2,p3 );
                handleUpdate(inserted,"Inserimento record" );

            } else {
                log:printError(<string>payload.detail().message);
            }
            
        } else if (mime:TEXT_PLAIN == baseType) {

            var payload = bodyPart.getText();
            if (payload is string) {
                log:printInfo(payload);
                payloadObj.printableContent=payload;
                jdbc:Parameter p2 = {sqlType: jdbc:TYPE_VARCHAR, value: payloadObj.printableContent};
                jdbc:Parameter p3 = {
                    sqlType: jdbc:TYPE_TIMESTAMP,
                    value: time:currentTime()
                };
        
                var inserted = testDB ->update("INSERT INTO payload(payload_content, insertedTime) values (?,?)", p2,p3 );
                handleUpdate(inserted,"Inserimento record" );

            } else {
                log:printError(<string>payload.detail().message);
            }
        } else if (mime:APPLICATION_PDF == baseType || mime:APPLICATION_OCTET_STREAM == baseType 
                || mime:IMAGE_GIF == baseType || mime:IMAGE_JPEG == baseType || mime:IMAGE_PNG == baseType) {
            
            var payload = bodyPart.getByteArray();
            if (payload is byte[]) {
                //Scrivi il payload su un file 
                //Salva il file su filesystem
                
                string path = "files/";
                string fullPath = path.concat(fileName);
                var err = writeToFile(fullPath,payload);
                
                jdbc:Parameter p2 = {sqlType: jdbc:TYPE_VARCHAR, value: payloadObj.printableContent};
                jdbc:Parameter p3 = {
                    sqlType: jdbc:TYPE_TIMESTAMP,
                    value: time:currentTime()
                };
        
                var inserted = testDB ->update("INSERT INTO payload(payload_content, insertedTime) values (?,?)", p2,p3 );
                handleUpdate(inserted,"Inserimento record" );
                payloadObj.fileName = fileName;
                payloadObj.printableContent = "file "+fileName+" salvato";
                payloadObj.httpStatusCode = http:STATUS_OK;
                log:printInfo("file salvato");
            } else {
       
                log:printError(<string>payload.detail().message);
                error uploadError = error("HFM-01: Binary Uplod Error: ", message = <string>payload.detail().message);
                return uploadError;
            }
        }

    }
    return payloadObj;
}

function objectToJson(Payload p) returns json {
   json jsonPayload = { message: p.getPrintableContent().toString(), 
   fileName: p.getFileName(), 
   httpStatusCode: p.getHttpStatusCode() 
   };
   return jsonPayload;
}

