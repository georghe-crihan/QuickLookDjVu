/* SPDX-FileCopyrightText: 2025 Blender Authors
 *
 * SPDX-License-Identifier: GPL-2.0-or-later 
 * Many thanks to GitHub / blender / blender / source/blender/blendthumb/src/thumbnail_provider.mm */

#import <AppKit/NSImage.h>
#include <optional>
#include <vector>
#include <unistd.h>
#include <fcntl.h>

#include "thumbnail_provider.h"

class FileDescriptorRAII {
 private:
  int src_fd = -1;

 public:
  explicit FileDescriptorRAII(const char *file_path)
  {
    src_fd = open(file_path, O_RDONLY, 0);
  }

  ~FileDescriptorRAII()
  {
    if (good()) {
      int ok = close(src_fd);
      if (!ok) {
        NSLog(@"DjVu Thumbnailer Error: Failed to close the DjVu file.");
      }
    }
  }

  bool good()
  {
    return src_fd > 0;
  }

  int get()
  {
    return src_fd;
  }
};

static NSError *create_nserror_from_string(NSString *errorStr)
{
  NSLog(@"DjVu Thumbnailer Error: %@", errorStr);
  return [NSError errorWithDomain:@"org.djvuzone.djvulibre.thumbnailer"
                             code:-1
                         userInfo:@{NSLocalizedDescriptionKey : errorStr}];
}

static NSImage *generate_nsimage_for_file(const char *src_djvu_path, NSError *error)
{
  /* Open source file `src_djvu`. */
  FileDescriptorRAII src_file_fd = FileDescriptorRAII(src_djvu_path);
  if (!src_file_fd.good()) {
    error = create_nserror_from_string(@"Failed to open DjVu");
    return nil;
  }

  FileReader *file_content = BLI_filereader_new_file(src_file_fd.get());
  if (file_content == nullptr) {
    error = create_nserror_from_string(@"Failed to read from djvu");
    return nil;
  }

  /* Extract thumbnail from file. */
  Thumbnail thumb;
  eThumbStatus err = djvuthumb_create_thumb_from_file(file_content, &thumb);
  if (err != BT_OK) {
    error = create_nserror_from_string(@"Failed to create thumbnail from file");
    return nil;
  }

  std::optional<std::vector<uint8_t>> png_buf_opt = djvuthumb_create_png_data_from_thumb(
      &thumb);
  if (!png_buf_opt) {
    error = create_nserror_from_string(@"Failed to create png data from thumbnail");
    return nil;
  }

  NSData *ns_data = [NSData dataWithBytes:png_buf_opt->data() length:png_buf_opt->size()];
  NSImage *ns_image = [[NSImage alloc] initWithData:ns_data];
  return ns_image;
}

@implementation ThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply *_Nullable reply,
                                                 NSError *_Nullable error))handler
{

  NSLog(@"Generating thumbnail for %@", request.fileURL.path);
  @autoreleasepool {
    NSError *error = nil;
    NSImage *image = generate_nsimage_for_file(request.fileURL.path.fileSystemRepresentation,
                                               error);
    if (image == nil || image.size.width <= 0 || image.size.height <= 0) {
      handler(nil, error);
      return;
    }

    const CGFloat width_ratio = request.maximumSize.width / image.size.width;
    const CGFloat height_ratio = request.maximumSize.height / image.size.height;
    const CGFloat scale_factor = MIN(width_ratio, height_ratio);

    const NSSize context_size = NSMakeSize(image.size.width * scale_factor,
                                           image.size.height * scale_factor);

    const NSRect context_rect = NSMakeRect(0, 0, context_size.width, context_size.height);

    QLThumbnailReply *thumbnailReply = [QLThumbnailReply replyWithContextSize:context_size
                                                   currentContextDrawingBlock:^BOOL {
                                                     [image drawInRect:context_rect];
                                                     /* Release the image that was strongly
                                                      * captured by this block. */
                                                     [image release];
                                                     return YES;
                                                   }];

    /* Return the thumbnail reply. */
    handler(thumbnailReply, nil);
  }
  NSLog(@"Thumbnail generation succcessfully completed");
}

@end
