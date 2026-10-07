const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const config = require('../config');

class StorageService {
  constructor() {
    this.s3Client = null;
    this.bucketName = process.env.S3_BUCKET_NAME || 'uploads';
    this.endpoint = process.env.S3_ENDPOINT;

    if (this.endpoint && process.env.S3_ACCESS_KEY_ID && process.env.S3_SECRET_ACCESS_KEY) {
      this.s3Client = new S3Client({
        region: process.env.S3_REGION || 'eu-central-1',
        endpoint: this.endpoint,
        credentials: {
          accessKeyId: process.env.S3_ACCESS_KEY_ID,
          secretAccessKey: process.env.S3_SECRET_ACCESS_KEY
        },
        forcePathStyle: true
      });
      console.log('✓ Neon Object Storage (S3) client configured');
    } else {
      console.log('ℹ S3 credentials not provided. Using local uploads directory fallback.');
      this.localUploadDir = path.join(__dirname, '../../uploads');
      if (!fs.existsSync(this.localUploadDir)) {
        fs.mkdirSync(this.localUploadDir, { recursive: true });
      }
    }
  }

  /**
   * Upload an image buffer and return public URL
   * @param {Buffer} fileBuffer 
   * @param {string} originalName 
   * @param {string} mimeType 
   * @returns {Promise<string>} Public URL of uploaded image
   */
  async uploadImage(fileBuffer, originalName, mimeType) {
    const ext = path.extname(originalName).toLowerCase() || '.jpg';
    const filename = `${crypto.randomUUID()}${ext}`;

    // If S3 / Neon Object Storage is configured
    if (this.s3Client) {
      const command = new PutObjectCommand({
        Bucket: this.bucketName,
        Key: `mosques/${filename}`,
        Body: fileBuffer,
        ContentType: mimeType,
        ACL: 'public-read'
      });

      await this.s3Client.send(command);

      const publicBaseUrl = process.env.S3_PUBLIC_URL || `${this.endpoint}/${this.bucketName}`;
      return `${publicBaseUrl}/mosques/${filename}`;
    }

    // Local fallback
    const filePath = path.join(this.localUploadDir, filename);
    await fs.promises.writeFile(filePath, fileBuffer);
    return `/uploads/${filename}`;
  }
}

module.exports = new StorageService();
