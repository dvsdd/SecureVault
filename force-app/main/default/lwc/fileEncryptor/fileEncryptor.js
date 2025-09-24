import { LightningElement, track } from 'lwc';
import verifyOtp from '@salesforce/apex/EncryptionService.verifyOtp';
import getFiles from '@salesforce/apex/EncryptionService.getFiles';
import decryptFile from '@salesforce/apex/EncryptionService.decryptFile';
import encryptAndSave from '@salesforce/apex/EncryptionService.encryptAndSave';
import sendOtp from '@salesforce/apex/EncryptionService.sendOtp';
import deleteFile from '@salesforce/apex/EncryptionService.deleteFile';
import signUp from '@salesforce/apex/EncryptionService.signUp';

export default class FileEncryptor extends LightningElement {
    // Sign-up
    @track signupEmail = '';
    @track signupPhone = '';

    // Login + OTP
    @track email = '';
    @track otp = '';
    @track otpVerified = false;

    // File list + decryption
    @track fileList = [];
    @track selectedFile;
    @track aesKey = '';
    @track decryptedData = '';

    // Encryption
    @track newFileName = '';
    @track newFileContent = '';
    @track generatedKey = '';
    @track cipherText = '';

    // Sign-up handlers
    handleSignupEmail(event) { this.signupEmail = event.target.value; }
    handleSignupPhone(event) { this.signupPhone = event.target.value; }
    registerUser() {
        signUp({ email: this.signupEmail, phone: this.signupPhone })
            .then(result => {
                if (result) {
                    alert('Sign-up successful. You can now log in with your email.');
                } else {
                    alert('An account with this email already exists.');
                }
            })
            .catch(error => { console.error('Sign-up failed', error); });
    }

    // Login + OTP
    handleEmailChange(event) { this.email = event.target.value; }
    handleOtpChange(event) { this.otp = event.target.value; }
    sendOtp() {
        sendOtp({ email: this.email })
            .then(() => { alert('OTP sent to your email'); })
            .catch(error => { console.error('Failed to send OTP', error); });
    }
    verifyOtp() {
        verifyOtp({ email: this.email, otp: this.otp })
            .then(result => {
                if (result) {
                    this.otpVerified = true;
                    return getFiles({ email: this.email });
                } else {
                    this.otpVerified = false;
                    alert('Invalid OTP');
                }
            })
            .then(files => { if (files) this.fileList = files; })
            .catch(error => { console.error('OTP verification failed', error); });
    }

    // File selection
    handleFileSelect(event) {
        const fileId = event.target.dataset.id;
        this.selectedFile = this.fileList.find(f => f.Id === fileId);
    }
    handleKeyChange(event) { this.aesKey = event.target.value; }
    decryptData() {
        decryptFile({ fileId: this.selectedFile.Id, base64Key: this.aesKey })
            .then(result => { this.decryptedData = result; })
            .catch(error => { console.error('Decryption failed', error); });
    }
    deleteFile() {
        deleteFile({ fileId: this.selectedFile.Id })
            .then(() => {
                alert('File deleted');
                this.fileList = this.fileList.filter(f => f.Id !== this.selectedFile.Id);
                this.selectedFile = null;
            })
            .catch(error => { console.error('Delete failed', error); });
    }

    // Encryption
    handleNewFileName(event) { this.newFileName = event.target.value; }
    handleNewFileContent(event) { this.newFileContent = event.target.value; }
    encryptData() {
        encryptAndSave({ fileName: this.newFileName, plainText: this.newFileContent, email: this.email })
            .then(result => {
                this.generatedKey = result.generatedKey;
                this.cipherText = result.cipherText;
                alert('File encrypted and saved. Key sent to your email.');
                return getFiles({ email: this.email });
            })
            .then(files => { this.fileList = files; })
            .catch(error => { console.error('Encryption failed', error); });
    }
}
