// TeethLink_Auth_System/src/modules/files/files.service.js
import multer from 'multer';

export const multerUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

export async function deleteStoredFileQuietly() {}

export function generateSignedFileUrl(key) {
  return key ? `/uploads/${key}` : null;
}

export async function insertFileRecord(client, data) {
  return {
    file_id: 1,
    storage_key: data.storageKey || 'mock_file.pdf',
  };
}

export async function validateAndStoreUploadedFile(file, purpose) {
  return {
    storageKey: `${purpose || 'doc'}_${Date.now()}.pdf`,
    originalName: file?.originalname || 'document.pdf',
    mimeType: file?.mimetype || 'application/pdf',
    sizeBytes: file?.size || 1024,
    sha256: 'mock_sha256_hash',
  };
}
