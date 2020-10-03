import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/docker;
//import ballerina/config;
import ballerina/observe;
import ballerina/io;
import ballerinax/java.jdbc;
import ballerina/time;


jdbc:Client testDB = new ({
    url: "jdbc:mysql://localhost:3306/testdb",
    username: "daniele",
    password: "secret",
    dbOptions: {useSSL: false}
});


@docker:Expose {}
listener http:Listener httpListener = new(9234
, config = {
    secureSocket: {
        keyStore: {
            
            path: "./security/ballerinaKeystore.p12",
            password: "ballerina"
        }
    }
});

http:Client clientEP = new ("http://localhost:9234");


@docker:Config {
    name: "http_filemanager",
    tag: "latest",
    push: true,
    registry: "quay.io/ddefrancesco",
    username: "ddefrancesco",
    password: "P4p3r1n0",
    cmd: "CMD java -jar upload.jar --b7a.observability.enabled=true"

}
@docker:CopyFiles {
   files: [
       { sourceFile: "src/upload/files/test.xml", target: "/home/ballerina/files/test.xml" }
       //{ sourceFile: "./security/ballerinaKeystore.p12", target: "/home/ballerina/security/ballerinaKeystore.p12" }
   ]
}

@http:ServiceConfig {
    basePath: "/multiparts"
}
service multipartService on httpListener {
        
        @http:ResourceConfig {
            methods: ["POST"],
            path: "/decode"
        }
        resource function multipartReceiver(http:Caller caller, http:Request request) returns error? {
            http:Response response = new;
            
            int spanId = check observe:startSpan("ReceiverSpan");
            // [Extracts bodyparts](https://ballerina.io/swan-lake/learn/api-docs/ballerina/http/objects/Request.html#getBodyParts) from the request.
            
            Payload|error? p = new;
             
            var bodyParts = request.getBodyParts();
            if (bodyParts is mime:Entity[]) {
                foreach var part in bodyParts {
                    mime:ContentDisposition contentDisposition = part.getContentDisposition();
                    
                    p = handleContent(part,<@untained>  contentDisposition.fileName);

                }
                
                //response.setPayload(<@untainted>bodyParts);
            } else {
                log:printError(<string>bodyParts.reason());
                response.setPayload("Error in decoding multiparts!");
                response.statusCode = 500;
            }
            int childSpanId = check observe:startSpan("CallEPSpan", (),
                                                            spanId);
            var result = caller->respond(response);
            if (result is error) {
                log:printError("Error sending response", result);
            }
            error? callEPResult = observe:finishSpan(childSpanId);
            error? obsResult = observe:finishSpan(spanId);
            
            return ();
        }


           @http:ResourceConfig {
                methods: ["GET"],
                path: "/encode"
            }
            resource function multipartSender(http:Caller caller, http:Request req) returns error? {
                int spanId = check observe:startSpan("SenderSpan");
                int childSpanId = check observe:startSpan("SetBodyPartsSpan", (),
                                                            spanId);
                mime:Entity jsonBodyPart = new;
                jsonBodyPart.setContentDisposition(
                                getContentDispositionForFormData("json part"));
                jsonBodyPart.setJson({"name": "wso2"});

                mime:Entity xmlFilePart = new;
                xmlFilePart.setContentDisposition(
                               getContentDispositionForFormData("xml file part"));

                xmlFilePart.setFileAsEntityBody("files/test.xml",
                                                contentType = mime:APPLICATION_XML);

                
                mime:Entity[] bodyParts = [jsonBodyPart, xmlFilePart];
                
                
                error? setBodyPartResult = observe:finishSpan(childSpanId);
                if (setBodyPartResult is error) {
                   log:printError("Error in finishing span", setBodyPartResult);
                }
                int childSpanId1 = check observe:startSpan("CallEPSpan", (),
                                                            spanId);
                http:Request request = new;

                request.setBodyParts(bodyParts, contentType = mime:MULTIPART_FORM_DATA);
                var returnResponse = clientEP->post("/multiparts/decode", request);
                if (returnResponse is http:Response) {
                    var result = caller->respond(returnResponse);
                    if (result is error) {
                        log:printError("Error sending response", result);
                    }
                } else {
                    http:Response response = new;
                    response.setPayload("Error occurred while sending multipart " +
                                            "request!");
                    response.statusCode = 500;
                    var result = caller->respond(response);
                    if (result is error) {
                        log:printError("Error sending response", result);
                    }
                }
                error? callEPResult = observe:finishSpan(childSpanId1);
                if (callEPResult is error) {
                   log:printError("Error in finishing span", callEPResult);
                }
                error? obsResult = observe:finishSpan(spanId);
                if (obsResult is error) {
                   log:printError("Error in finishing span", obsResult);
                }                
                return ();
            }
        }

         function handleContent(mime:Entity bodyPart,string fileName) returns @tainted Payload|error?{
            Payload payloadObj = new; 
            
            var mediaType = mime:getMediaType(bodyPart.getContentType());
            log:printInfo(">>>>handle content begin<<<<");
            if (mediaType is mime:MediaType) {
                string baseType = mediaType.getBaseType();
                log:printDebug("baseType "+ baseType);
                if (mime:APPLICATION_XML == baseType || mime:TEXT_XML == baseType) {

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
                } else if (mime:APPLICATION_PDF == baseType || mime:APPLICATION_OCTET_STREAM == baseType) {
                    
                    var payload = bodyPart.getByteArray();
                    if (payload is byte[]) {
                        //Scrivi il payload su un file 
                        //Salva il file su filesystem
                        
                        string path = "files/";
                        string fullPath = path.concat(fileName);
                        var err = writeToFile(fullPath,payload);
                        
                        payloadObj.printableContent = "file "+fileName+" salvato";
                        jdbc:Parameter p2 = {sqlType: jdbc:TYPE_VARCHAR, value: payloadObj.printableContent};
                        jdbc:Parameter p3 = {
                            sqlType: jdbc:TYPE_TIMESTAMP,
                            value: time:currentTime()
                        };
                
                        var inserted = testDB ->update("INSERT INTO payload(payload_content, insertedTime) values (?,?)", p2,p3 );
                        handleUpdate(inserted,"Inserimento record" );

                        log:printInfo("file salvato");
                    } else {
                        log:printError(<string>payload.detail().message);
                    }
                }

            }
            return payloadObj;
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




