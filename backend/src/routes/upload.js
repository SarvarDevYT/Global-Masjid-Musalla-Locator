const express = require('express');
const multer = require('multer');
const storageService = require('../services/storageService');

const router = express.Router();

// Vercel funksiyalarida so'rov hajmi ~4.5MB bilan cheklangan
const MAX_BYTES = 4 * 1024 * 1024;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: 1 },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    cb(null, allowedMimes.includes(file.mimetype));
  }
});

// Mijoz bergan MIME turiga ishonmaymiz: fayl boshidagi "magic bytes" tekshiriladi
function detectImageType(buf) {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { mime: 'image/jpeg', ext: 'jpg' };
  if (buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return { mime: 'image/png', ext: 'png' };
  }
  if (buf.subarray(0, 4).toString('ascii') === 'RIFF' && buf.subarray(8, 12).toString('ascii') === 'WEBP') {
    return { mime: 'image/webp', ext: 'webp' };
  }
  return null;
}

/**
 * POST /api/v1/upload  (multipart/form-data, maydon: "photo")
 */
router.post('/', (req, res, next) => {
  upload.single('photo')(req, res, async (err) => {
    if (err) {
      const tooLarge = err.code === 'LIMIT_FILE_SIZE';
      return res.status(tooLarge ? 413 : 400).json({
        success: false,
        error: tooLarge ? 'Rasm hajmi 4 MB dan oshmasligi kerak.' : 'Rasm yuklashda xatolik.'
      });
    }

    try {
      if (!req.file) {
        return res.status(400).json({
          success: false,
          error: 'Faqat JPEG, PNG yoki WEBP formatdagi rasm qabul qilinadi.'
        });
      }

      const detected = detectImageType(req.file.buffer);
      if (!detected) {
        return res.status(400).json({ success: false, error: 'Fayl haqiqiy rasm emas.' });
      }

      const url = await storageService.uploadImage(req.file.buffer, `photo.${detected.ext}`, detected.mime);
      res.status(201).json({ success: true, message: 'Rasm muvaffaqiyatli yuklandi.', url });
    } catch (e) {
      next(e);
    }
  });
});

module.exports = router;
