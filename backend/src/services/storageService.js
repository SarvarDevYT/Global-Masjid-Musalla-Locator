const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const config = require('../config');

class StorageService {
  constructor() {
    this.s3Client = null;
    this.endpoint = process.env.AWS_ENDPOINT_URL_S3 || process.env.S3_ENDPOINT;
    this.bucketName = process.env.S3_BUCKET || process.env.S3_BUCKET_NAME || 'uploads';
    const accessKeyId = process.env.AWS_ACCESS_KEY_ID || process.env.S3_ACCESS_KEY_ID;
    const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY || process.env.S3_SECRET_ACCESS_KEY;
    const region = process.env.AWS_REGION || process.env.S3_REGION || 'eu-central-1';

    if (this.endpoint && accessKeyId && secretAccessKey) {
      this.s3Client = new S3Client({
        region: region,
        endpoint: this.endpoint,
        credentials: {
          accessKeyId: accessKeyId,
          secretAccessKey: secretAccessKey
        },
        forcePathStyle: true
      });
      console.log('✓ Neon Object Storage (S3) client configured');
    } else {
      console.log('ℹ S3 credentials not provided. Using local uploads directory fallback.');
      try {
        this.localUploadDir = path.join(__dirname, '../../uploads');
        if (!fs.existsSync(this.localUploadDir)) {
          fs.mkdirSync(this.localUploadDir, { recursive: true });
        }
      } catch {
        // Faqat o'qish uchun fayl tizimi (serverless): lokal saqlash mavjud emas
        this.localUploadDir = null;
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
        ContentType: mimeType
      });

      await this.s3Client.send(command);

      const publicBaseUrl = process.env.S3_PUBLIC_URL || `${this.endpoint}/${this.bucketName}`;
      return `${publicBaseUrl}/mosques/${filename}`;
    }

    // Local fallback
    if (!this.localUploadDir) {
      throw new Error('Storage is not configured');
    }
    const filePath = path.join(this.localUploadDir, filename);
    await fs.promises.writeFile(filePath, fileBuffer);
    return `/uploads/${filename}`;
  }
}

module.exports = new StorageService();
