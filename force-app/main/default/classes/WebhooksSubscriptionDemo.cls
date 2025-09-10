@RestResource(urlMapping = '/api/Webhooks/pushDetailsDemo/*')
global class WebhooksSubscriptionDemo {
    public class pusher {
        public String name;
        public String email;
    }
    
    public class head_commit {
        public String id;
        public String message;
        public String timestamp;
        public String url;
        public List<String> added;
        public List<String> removed;
        public List<String> modified;
    }

    public class SDFCResponse {
        public String status;
        public String message;
        
        public SDFCResponse(String s, String m) {
            status = s;
            message = m;
        }
    }

	@HttpPost
    global static void handleNotification(){
        try {
            RestRequest request = RestContext.request;
            RestResponse response = RestContext.response;
            
            // Fetching headers
            String hashedval = request.headers.get('X-Hub-Signature-256');
            System.debug('hashedval:' + hashedval);
            
            Blob bB = request.requestBody;
            System.debug(bB.toString());
            
            // HMAC validation
            String secret = 'webhooktrial';
            Blob hmac = Crypto.generateMac('hmacSHA256', bB, Blob.valueOf(secret));
            String hmacstring = 'sha256=' + EncodingUtil.convertToHex(hmac);
            System.debug('hmac => '+EncodingUtil.convertToHex(hmac));
            
            if (hashedval == hmacstring) {
                pusher ps;
                head_commit hc;
                String repo;
                
                JSONParser parser = JSON.createParser(request.requestBody.toString());
                while (parser.nextToken() != null) {
                    if (parser.getText() == 'pusher') {
                        parser.nextToken();
                        ps = (pusher)JSON.deserialize(parser.getText(), pusher.class);
                        System.debug(ps);
                    }
                    if (parser.getText() == 'head_commit') {
                        parser.nextToken();
                        hc = (head_commit)JSON.deserialize(parser.getText(), head_commit.class);
                        System.debug(hc);
                    }
                    if (parser.getText() == 'full_name') {
                        parser.nextToken();
                        repo = parser.getText();
                        System.debug(repo);
                    }
                }
                
                // Insert record
                GitHub_Push_Details__c detail = new GitHub_Push_Details__c();
                detail.Committer_Name__c = ps != null ? ps.name : '';
                detail.Committer_Email__c = ps != null ? ps.email : '';
                detail.Commit_Message__c = hc != null ? hc.message : '';
                detail.Commit_Timestamp__c = hc != null ? hc.timestamp : '';
                detail.Committed_URL__c = hc != null ? hc.url : '';
                detail.Repository_Name__c = repo;
                detail.Added_Components__c = (hc != null && hc.added != null) ? String.join(hc.added, ',') : '';
                detail.Removed_Components__c = (hc != null && hc.removed != null) ? String.join(hc.removed, ',') : '';
                detail.Modified_Components__c = (hc != null && hc.modified != null) ? String.join(hc.modified, ',') : '';
                insert detail;
                
                response.statusCode = 200;
                response.responseBody = Blob.valueOf(JSON.serialize(new SDFCResponse('Success', 'Processed Successfully')));
            }
        } catch (Exception e) {
            System.debug('Exception Happened: ' + e.getMessage());
        }
    }
}