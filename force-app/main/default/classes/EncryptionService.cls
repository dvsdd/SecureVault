public with sharing class EncryptionService {

    // 🔹 Sign-Up method
    @AuraEnabled
    public static Boolean signUp(String email, String phone) {
        // Check if customer already exists
        List<cry_Customer__c> existing = [
            SELECT Id FROM cry_Customer__c WHERE Email__c = :email LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return false; // Already exists
        }

        // Create new customer
        cry_Customer__c cust = new cry_Customer__c(
            Email__c = email,
            Phone_Number__c = phone
        );
        insert cust;
        return true;
    }

    // 🔹 Encrypt and save file
    @AuraEnabled
    public static Map<String, String> encryptAndSave(String fileName, String plainText, String email) {
        Blob key = Crypto.generateAesKey(128);
        Blob data = Blob.valueOf(plainText);
        Blob encrypted = Crypto.encryptWithManagedIV('AES128', key, data);

        String base64Key = EncodingUtil.base64Encode(key);
        String cipherText = EncodingUtil.base64Encode(encrypted);

        File_encrypt__c fileRec = new File_encrypt__c();
        fileRec.Name = fileName;
        fileRec.Email_id__c = email;
        fileRec.Encrypted_Content__c = cipherText;
        insert fileRec;

        // Send encryption key to user
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { email });
        mail.setSubject('Your Encryption Key');
        mail.setPlainTextBody(
            'Your encryption key for file "' + fileName + '" is: ' + base64Key +
            '\n\n⚠️ Keep this safe. If you lose it, your data cannot be recovered.'
        );
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        Map<String, String> result = new Map<String, String>();
        result.put('generatedKey', base64Key);
        result.put('cipherText', cipherText);
        return result;
    }

    // 🔹 Decrypt file
    @AuraEnabled
    public static String decryptFile(Id fileId, String base64Key) {
        File_encrypt__c fileRec = [
            SELECT Encrypted_Content__c 
            FROM File_encrypt__c 
            WHERE Id = :fileId 
            LIMIT 1
        ];
        Blob key = EncodingUtil.base64Decode(base64Key);
        Blob encrypted = EncodingUtil.base64Decode(fileRec.Encrypted_Content__c);
        Blob decrypted = Crypto.decryptWithManagedIV('AES128', key, encrypted);
        return decrypted.toString();
    }

    // 🔹 Get files for a user
    @AuraEnabled
    public static List<File_encrypt__c> getFiles(String email) {
        return [
            SELECT Id, Name 
            FROM File_encrypt__c 
            WHERE Email_id__c = :email
        ];
    }

    // 🔹 Delete file
    @AuraEnabled
    public static Boolean deleteFile(Id fileId) {
        delete [SELECT Id FROM File_encrypt__c WHERE Id = :fileId LIMIT 1];
        return true;
    }

    // 🔹 Send OTP
    @AuraEnabled
    public static Boolean sendOtp(String email) {
        Integer raw = Math.abs(Crypto.getRandomInteger());
        Integer modVal = Math.mod(raw, 1000000);
        String otp = String.valueOf(modVal);
        while (otp.length() < 6) {
            otp = '0' + otp;
        }

        cry_Customer__c cust = [
            SELECT Id FROM cry_Customer__c WHERE Email__c = :email LIMIT 1
        ];

        cust.OTP__c = otp;
        cust.OTP_Expiry__c = System.now().addMinutes(5);
        update cust;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { email });
        mail.setSubject('Your One‑Time Password');
        mail.setPlainTextBody('Your OTP is: ' + otp + ' (valid for 5 minutes)');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        return true;
    }

    // 🔹 Verify OTP
    @AuraEnabled
    public static Boolean verifyOtp(String email, String otp) {
        cry_Customer__c cust = [
            SELECT Id, OTP__c, OTP_Expiry__c 
            FROM cry_Customer__c 
            WHERE Email__c = :email 
            LIMIT 1
        ];
        if (cust != null && cust.OTP__c == otp && cust.OTP_Expiry__c > System.now()) {
            return true;
        }
        return false;
    }
}
