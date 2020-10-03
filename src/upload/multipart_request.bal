import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/docker;
//import ballerina/config;
import ballerina/observe;
import ballerinax/java.jdbc;



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
            json jsonResponse = {};
            int spanId = check observe:startSpan("ReceiverSpan");
            // [Extracts bodyparts](https://ballerina.io/swan-lake/learn/api-docs/ballerina/http/objects/Request.html#getBodyParts) from the request.
            
            Payload|error? p = new;
             
            var bodyParts = request.getBodyParts();
            if (bodyParts is mime:Entity[]) {
                foreach var part in bodyParts {
                    mime:ContentDisposition contentDisposition = part.getContentDisposition();
                    
                    p = handleContent(part,<@untained>  contentDisposition.fileName);
                    
                }
                if (p is Payload) {
                    jsonResponse = objectToJson(p);
                }
                response.statusCode = http:STATUS_OK;
                response.setJsonPayload(jsonResponse);
            } else {
                log:printError(<string>bodyParts.reason());
                
                jsonResponse = {message: "Error in decoding multiparts!", code: http:STATUS_INTERNAL_SERVER_ERROR };
                response.statusCode = http:STATUS_INTERNAL_SERVER_ERROR;
                response.setJsonPayload(jsonResponse);
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
                    response.setJsonPayload("Error occurred while sending multipart " +
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

