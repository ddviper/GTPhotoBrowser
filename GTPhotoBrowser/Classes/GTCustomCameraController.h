//
//  GTCustomCameraController.h
//  GPUImage
//
//  Created by liuxc on 2018/6/30.
//

#import <UIKit/UIKit.h>
#import "GTPhotoDefine.h"

@interface GTCustomCameraController : UIViewController

@property (nonatomic, assign) CFTimeInterval maxRecordTime;

//是否允许拍照
@property (nonatomic, assign) BOOL allowTakePhoto;
//是否允许录制视频
@property (nonatomic, assign) BOOL allowRecordVideo;

//最大录制时长
@property (nonatomic, assign) NSInteger maxRecordDuration;

@property (nonatomic, assign) GTCaptureSessionPreset sessionPreset;

@property (nonatomic, assign) GTExportVideoType videoType;

//录制视频时候进度条颜色
@property (nonatomic, strong) UIColor *circleProgressColor;

/**
 确定回调，如果拍照则videoUrl为nil，如果视频则image为nil
 */
@property (nonatomic, copy) void (^doneBlock)(UIImage *image, NSURL *videoUrl);

@end
