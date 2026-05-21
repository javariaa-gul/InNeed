import { Injectable, InternalServerErrorException, BadRequestException } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';

@Injectable()
export class CloudinaryService {
  private configured = false;

  private ensureConfigured() {
    if (this.configured) {
      return;
    }

    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;

    if (!cloudName || !apiKey || !apiSecret) {
      throw new InternalServerErrorException(
        'Cloudinary configuration missing. Check CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET',
      );
    }

    cloudinary.config({
      cloud_name: cloudName,
      api_key: apiKey,
      api_secret: apiSecret,
    });

    this.configured = true;
  }

  /**
   * Upload a single image to Cloudinary
   * @param file - Multer file object
   * @param folder - Cloudinary folder path
   * @returns Secure URL of uploaded image
   */
  async uploadImage(file: Express.Multer.File, folder = 'apka-hunar/default'): Promise<string> {
    if (!file) {
      throw new BadRequestException('File is required');
    }

    if (!file.buffer || file.buffer.length === 0) {
      throw new BadRequestException('File is empty');
    }

    this.ensureConfigured();

    return new Promise((resolve, reject) => {
      const upload = cloudinary.uploader.upload_stream(
        {
          folder,
          resource_type: 'auto',
          timeout: 60000,
        },
        (error, result) => {
          if (error) {
            console.error('[Cloudinary Error]', error);
            reject(
              new InternalServerErrorException(
                `Image upload failed: ${error.message || 'Unknown error'}`,
              ),
            );
          } else if (result?.secure_url) {
            resolve(result.secure_url);
          } else {
            reject(new InternalServerErrorException('Upload succeeded but no URL returned'));
          }
        },
      );

      upload.end(file.buffer);
    });
  }

  /**
   * Upload multiple images in parallel
   * @param files - Array of Multer file objects
   * @param folder - Cloudinary folder path
   * @returns Array of secure URLs
   */
  async uploadMultipleImages(
    files: Express.Multer.File[],
    folder = 'apka-hunar/default',
  ): Promise<string[]> {
    if (!files || files.length === 0) {
      throw new BadRequestException('At least one file is required');
    }

    try {
      const uploadPromises = files.map((file) => this.uploadImage(file, folder));
      return await Promise.all(uploadPromises);
    } catch (error) {
      throw error;
    }
  }

  /**
   * Delete image from Cloudinary
   * @param publicId - Cloudinary public ID
   */
  async deleteImage(publicId: string): Promise<void> {
    if (!publicId) {
      throw new BadRequestException('Public ID is required');
    }

    this.ensureConfigured();

    return new Promise((resolve, reject) => {
      cloudinary.uploader.destroy(publicId, (error, result) => {
        if (error) {
          console.error('[Cloudinary Delete Error]', error);
          reject(new InternalServerErrorException('Image deletion failed'));
        } else {
          resolve();
        }
      });
    });
  }
}