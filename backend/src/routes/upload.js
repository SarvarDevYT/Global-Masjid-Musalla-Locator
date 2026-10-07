const express = require('express');
const multer = require('multer');
const storageService = require('../services/storageService');

const router = express.Router();

// Configure multer memory storage with strict validation
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024 // 5 MB maximum
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Faqat JPEG, PNG yoki WEBP formatdagi rasmlar qabul qilinadi.'));
    }
  }
});

/**
 * POST /api/v1/upload
 * Upload image to Neon Object Storage
 */
router.post('/', upload.single('photo'), async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'Rasm fayli yuklanmadi.'
      });
    }

    const fileUrl = await storageService.uploadImage(
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype
    );

    res.status(201).json({
      success: true,
      message: 'Rasm muvaffaqiyatli yuklandi.',
      url: fileUrl
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
