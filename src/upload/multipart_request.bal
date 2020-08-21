import ballerina/http;
import ballerina/log;
import ballerina/mime;
import ballerina/docker;

@docker:Expose {}
listener http:Listener httpListener = new(9090);

http:Client clientEP = new ("http://localhost:9090");

@http:ServiceConfig {
    basePath: "/multiparts"
}

@docker:Config {
    name: "http_filemanager",
    tag: "v1.0",
    push: true,
    registry: "quay.io/ddefrancesco",
    username: "ddefrancesco",
    password: "P4p3r1n0"
}
service multipartService on httpListener {

        @http:ResourceConfig {
            methods: ["POST"],
            path: "/decode"
        }
        resource function multipartReceiver(http:Caller caller, http:Request request) {
            http:Response response = new;
            // [Extracts bodyparts](https://ballerina.io/swan-lake/learn/api-docs/ballerina/http/objects/Request.html#getBodyParts) from the request.

            var bodyParts = request.getBodyParts();
            if (bodyParts is mime:Entity[]) {
                foreach var part in bodyParts {
                    handleContent(part);
                }
                response.setPayload(<@untainted>bodyParts);
            } else {
                log:printError(<string>bodyParts.reason());
                response.setPayload("Error in decoding multiparts!");
                response.statusCode = 500;
            }
            var result = caller->respond(response);
            if (result is error) {
                log:printError("Error sending response", result);
            }
        }


           @http:ResourceConfig {
                methods: ["GET"],
                path: "/encode"
            }
            resource function multipartSender(http:Caller caller, http:Request req) {
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
            }
        }

        function handleContent(mime:Entity bodyPart) {
            var mediaType = mime:getMediaType(bodyPart.getContentType());
            if (mediaType is mime:MediaType) {
                string baseType = mediaType.getBaseType();
                if (mime:APPLICATION_XML == baseType || mime:TEXT_XML == baseType) {

                    var payload = bodyPart.getXml();
                    if (payload is xml) {
                        log:printInfo(payload.toString());
                    } else {
                        log:printError(<string>payload.detail().message);
                    }
                } else if (mime:APPLICATION_JSON == baseType) {

                    var payload = bodyPart.getJson();
                    if (payload is json) {
                        log:printInfo(payload.toJsonString());
                    } else {
                        log:printError(<string>payload.detail().message);
                    }
                } else if (mime:TEXT_PLAIN == baseType) {

                    var payload = bodyPart.getText();
                    if (payload is string) {
                        log:printInfo(payload);
                    } else {
                        log:printError(<string>payload.detail().message);
                    }
                }
            }
        }

        function getContentDispositionForFormData(string partName)
                                            returns (mime:ContentDisposition) {
            mime:ContentDisposition contentDisposition = new;
            contentDisposition.name = partName;
            contentDisposition.disposition = "form-data";
            return contentDisposition;
        }



