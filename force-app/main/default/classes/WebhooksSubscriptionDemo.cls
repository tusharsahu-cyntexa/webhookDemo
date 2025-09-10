@RestResource(urlMapping = '/api/Webhooks/pushDetailsDemo/*')
global with sharing class WebhooksSubscriptionDemo {
    global class Pusher {
        public String name;
        public String email;
    }
    global class HeadCommit {
        public String id;
        public String message;
        public String timestamp;
        public String url;
        public List<String> added;
        public List<String> removed;
        public List<String> modified;
    }
    global class Repository {
        public String full_name;
    }
    global class GitHubPayload {
        public Pusher pusher;
        public HeadCommit head_commit;
        public Repository repository;
    }
    global class SDFCResponse {
        public String status;
        public String message;
        public SDFCResponse(String s, String m) {
            status = s;
            message = m;
        }
    }

    @HttpPost
    global static void handleNotification() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;
        try {
            // --- Step 1: Get signature from header
            String incomingSignature = request.headers.get('X-Hub-Signature-256');
            System.debug('GitHub Signature: ' + incomingSignature);

            // --- Step 2: Compute HMAC with secret
            String secret = 'webhooktrail';
            Blob payloadBlob = request.requestBody;
            Blob hmac = Crypto.generateMac('hmacSHA256', payloadBlob, Blob.valueOf(secret));
            String computedSignature = 'sha256=' + EncodingUtil.convertToHex(hmac);
            System.debug('Computed Signature: ' + computedSignature);

            // --- Step 3: Compare
            if (incomingSignature == null || incomingSignature != computedSignature) {
                response.statusCode = 401;
                response.responseBody = Blob.valueOf(JSON.serialize(new SDFCResponse('Error', 'Invalid Signature')));
                System.debug('Signature mismatch – rejecting request');
                return;
            }

            // --- Step 4: Deserialize JSON
            String body = payloadBlob.toString();
            System.debug('Incoming Payload: ' + body);

            GitHubPayload payload = (GitHubPayload) JSON.deserialize(body, GitHubPayload.class);

            // --- Step 5: Insert record
            GitHub_Push_Details__c detail = new GitHub_Push_Details__c();
            detail.Committer_Name__c = payload.pusher != null ? payload.pusher.name : '';
            detail.Committer_Email__c = payload.pusher != null ? payload.pusher.email : '';
            detail.Commit_Message__c = payload.head_commit != null ? payload.head_commit.message : '';
            detail.Commit_Timestamp__c = payload.head_commit != null ? payload.head_commit.timestamp : '';
            detail.Committed_URL__c = payload.head_commit != null ? payload.head_commit.url : '';
            detail.Repository_Name__c = payload.repository != null ? payload.repository.full_name : '';
            detail.Added_Components__c = (payload.head_commit != null && payload.head_commit.added != null) ? String.join(payload.head_commit.added, ',') : '';
            detail.Removed_Components__c = (payload.head_commit != null && payload.head_commit.removed != null) ? String.join(payload.head_commit.removed, ',') : '';
            detail.Modified_Components__c = (payload.head_commit != null && payload.head_commit.modified != null) ? String.join(payload.head_commit.modified, ',') : '';

            insert detail;

            response.statusCode = 200;
            response.responseBody = Blob.valueOf(JSON.serialize(new SDFCResponse('Success', 'Processed Successfully')));
        } catch (Exception e) {
            System.debug('Exception Happened: ' + e.getMessage() + ' : ' + e.getStackTraceString());
            response.statusCode = 500;
            response.responseBody = Blob.valueOf(JSON.serialize(new SDFCResponse('Error', e.getMessage())));
        }
    }
}
