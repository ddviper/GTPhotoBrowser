//
//  UIImage+GTPhotoBrowser.h
//  GPUImage
//
//  Created by liuxc on 2018/6/30.
//

#import <UIKit/UIKit.h>

@interface UIImage (GTPhotoBrowser)

- (UIImage*)rotate:(UIImageOrientation)orient;

+ (UIImage *)createImageWithColor:(UIColor *)color size:(CGSize)size radius:(CGFloat)radius;

@end
