//
//  CameraChangeFaceViewController.m
//  VisionLearn
//
//  Created by hong-drmk on 2017/11/2.
//  Copyright © 2017年 Dasen. All rights reserved.
//

#import "CameraChangeFaceViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface CameraChangeFaceViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_dataOutput;
    AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;
    CFAbsoluteTime _preCaptureTime;
}

@property (nonatomic, strong)NSMutableArray *faceImageViews;

@end

@implementation CameraChangeFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"实时交换人脸";
    
    // 请求授权
    [self getAuthorization];
}

/// 初始化相关内容
- (void)initCapture
{
    [self addSession];
    [_captureSession beginConfiguration];
    
    [self addVideo];
    [self addPreviewLayer];
    
    [_captureSession commitConfiguration];
    [_captureSession startRunning];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _captureVideoPreviewLayer.frame = self.view.bounds;
}

/// 添加预览视图
- (void)addPreviewLayer
{
    // 通过会话 (AVCaptureSession) 创建预览层
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _captureVideoPreviewLayer.frame = self.view.bounds;
    
    //有时候需要拍摄完整屏幕大小的时候可以修改这个
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//    _captureVideoPreviewLayer.connection.videoOrientation = 3;
    
    // 显示在视图表面的图层
    CALayer *layer = self.view.layer;
    layer.masksToBounds = true;
    [self.view layoutIfNeeded];
    [layer addSublayer:_captureVideoPreviewLayer];
}

/// 添加video
- (void)addVideo
{
    //摄像头前后
    _videoDevice = [self deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
    
    [self addVideoInput];
    [self addDataOutput];
}

/// 添加videoinput
- (void)addVideoInput
{
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:NULL];
    
    // 将视频输入对象添加到会话 (AVCaptureSession) 中
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
}

/// 添加数据输出
- (void)addDataOutput
{
    // 拍摄视频输出对象
    // 初始化输出设备对象，用户获取输出数据
    _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_dataOutput setSampleBufferDelegate:self queue:dispatch_queue_create("CameraCaptureSampleBufferDelegateQueue", NULL)];
    [_dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];

    
    if ([_captureSession canAddOutput:_dataOutput]) {
        [_captureSession addOutput:_dataOutput];
        AVCaptureConnection *captureConnection = [_dataOutput connectionWithMediaType:AVMediaTypeVideo];
        
        if ([captureConnection isVideoOrientationSupported]) {
            [captureConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
        // 视频稳定设置
        if ([captureConnection isVideoStabilizationSupported]) {
            captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        
        // 设置输出图片方向
//        captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
}

- (void)addSession
{
    _captureSession = [[AVCaptureSession alloc] init];
    //设置视频分辨率
    //注意,这个地方设置的模式/分辨率大小将影响你后面拍摄照片/视频的大小,
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    }
}

/// 获取设备
- (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    
    for ( AVCaptureDevice *device in devices ) {
        if ( device.position == position ) {
            captureDevice = device;
            break;
        }
    }
    return captureDevice;
}

- (NSMutableArray *)faceImageViews
{
    if (!_faceImageViews) {
        _faceImageViews = @[].mutableCopy;
    }
    return _faceImageViews;
}

- (void)getAuthorization
{
    AVAuthorizationStatus videoStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (videoStatus)
    {
        case AVAuthorizationStatusAuthorized:
        case AVAuthorizationStatusNotDetermined:
            [self initCapture];
            break;
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            [self showMsgWithTitle:@"相机未授权" andContent:@"请打开设置-->隐私-->相机-->快射-->开启权限"];
            break;
        default:
            break;
    }
}

- (void)showMsgWithTitle:(NSString *)title andContent:(NSString *)content
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:content delegate:nil
                                          cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alert addButtonWithTitle:@"去开启"];
    [alert show];
    alert.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // 强制横屏
//    if([[UIDevice currentDevice]respondsToSelector:@selector(setOrientation:)]) {
//
//        SEL selector = NSSelectorFromString(@"setOrientation:");
//
//        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
//
//        [invocation setSelector:selector];
//
//        [invocation setTarget:[UIDevice currentDevice]];
//
//        int val = UIInterfaceOrientationLandscapeRight;//横屏
//
//        [invocation setArgument:&val atIndex:2];
//
//        [invocation invoke];
//
//    }
}

-(void)pop
{
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Delegate
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

/// 获取输出
- (void)captureOutput:(AVCaptureFileOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (currentTime - _preCaptureTime <= 0.2) {
        return;
    }
    _preCaptureTime = currentTime;
    
    CVPixelBufferRef BufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    UIImage *sourceImage = [self imageFromPixelBuffer:sampleBuffer];
    VNDetectFaceLandmarksRequest *detectFaceRequest = [[VNDetectFaceLandmarksRequest alloc ]init];
    VNImageRequestHandler *detectFaceRequestHandler = [[VNImageRequestHandler alloc]initWithCVPixelBuffer:BufferRef options:@{}];
    
    [detectFaceRequestHandler performRequests:@[detectFaceRequest] error:nil];
    NSArray *results = detectFaceRequest.results;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        for (UIView *view in self.faceImageViews) {
            [view removeFromSuperview];
        }
        
        [self.faceImageViews removeAllObjects];

        CGRect sourceRect = self.view.bounds;
        NSMutableArray <UIImage *>*facesImage = @[].mutableCopy;
        NSMutableArray <NSValue *>*facesRect = @[].mutableCopy;
        
        for (VNFaceObservation *observation  in results) {
            
            VNFaceLandmarkRegion2D *faceContour = observation.landmarks.faceContour;
            VNFaceLandmarkRegion2D *leftEyebrow = observation.landmarks.leftEyebrow;
            VNFaceLandmarkRegion2D *rightEyebrow = observation.landmarks.rightEyebrow;
            CGFloat faceMinX = CGFLOAT_MAX;
            CGFloat faceMinY = CGFLOAT_MAX;
            CGFloat faceMaxX = CGFLOAT_MIN;
            CGFloat faceMaxY = CGFLOAT_MIN;
            NSInteger pointCount = faceContour.pointCount + leftEyebrow.pointCount + rightEyebrow.pointCount;
            CGPoint points[pointCount];
            
            //转换所有脸部轮廓特征点
            CGFloat rectWidth = observation.boundingBox.size.width * sourceRect.size.width;
            CGFloat rectHeight = observation.boundingBox.size.height * sourceRect.size.height;
            CGFloat rectX = observation.boundingBox.origin.x * sourceRect.size.width;
            CGFloat rectY = (1 - observation.boundingBox.origin.y) * sourceRect.size.height - rectHeight;
            
            for (int i = 0; i < faceContour.pointCount; i ++) {
                //从左向右
                NSUInteger index = i + 0;
                CGPoint point = faceContour.normalizedPoints[index];
                CGPoint p = CGPointMake(rectX + point.x * rectWidth,
                                        rectY + (1 - point.y) * rectHeight);
                points[index] = p;
                faceMinX = faceMinX > p.x ? p.x : faceMinX;
                faceMinY = faceMinY > p.y ? p.y : faceMinY;
                faceMaxX = faceMaxX < p.x ? p.x : faceMaxX;
                faceMaxY = faceMaxY < p.y ? p.y : faceMaxY;
            }
            for (int i = 0; i < rightEyebrow.pointCount; i ++) {
                //从左向右 -> 从右向左
                //右眉毛的最右边 接着 脸廓的右边
                CGPoint point = rightEyebrow.normalizedPoints[rightEyebrow.pointCount - i - 1];
                CGPoint p = CGPointMake(rectX + point.x * rectWidth,
                                        rectY + (1 - point.y) * rectHeight);
                NSUInteger index = i + faceContour.pointCount;
                points[index] = p;
                faceMinX = faceMinX > p.x ? p.x : faceMinX;
                faceMinY = faceMinY > p.y ? p.y : faceMinY;
                faceMaxX = faceMaxX < p.x ? p.x : faceMaxX;
                faceMaxY = faceMaxY < p.y ? p.y : faceMaxY;
            }
            for (int i = 0; i < leftEyebrow.pointCount; i ++) {
                //从左向右 -> 从右向左
                //左眉毛的最右边 接着 右眉毛的左边
                CGPoint point = leftEyebrow.normalizedPoints[leftEyebrow.pointCount - i - 1];
                CGPoint p = CGPointMake(rectX + point.x * rectWidth,
                                        rectY + (1 - point.y) * rectHeight);
                NSUInteger index = i + faceContour.pointCount + rightEyebrow.pointCount;
                points[index] = p;
                faceMinX = faceMinX > p.x ? p.x : faceMinX;
                faceMinY = faceMinY > p.y ? p.y : faceMinY;
                faceMaxX = faceMaxX < p.x ? p.x : faceMaxX;
                faceMaxY = faceMaxY < p.y ? p.y : faceMaxY;
            }
            
            UIImage *faceImage = nil;
            
            //抠脸图
            UIGraphicsBeginImageContextWithOptions(sourceRect.size, NO, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [[UIColor greenColor] set];
            CGContextSetLineWidth(context, 2);
            
            // 设置线类型
            CGContextSetLineJoin(context, kCGLineJoinRound);
            CGContextSetLineCap(context, kCGLineCapRound);
            
            // 设置抗锯齿
            CGContextSetShouldAntialias(context, true);
            CGContextSetAllowsAntialiasing(context, true);
            
            // 绘制
            CGContextAddLines(context, points, pointCount);
            CGContextClosePath(context);
            CGContextClip(context);
            
            CGRect rect = CGRectMake(0, 0, sourceRect.size.width, sourceRect.size.height);
            [sourceImage drawInRect:rect];
            faceImage = UIGraphicsGetImageFromCurrentImageContext();
            
            // 结束绘制
            UIGraphicsEndImageContext();
            
            if (faceImage) {
                //把其他透明区域去掉，只留脸的区域
                CGFloat scale = [UIScreen mainScreen].scale;
                CGRect rect = CGRectMake(faceMinX, faceMinY, faceMaxX - faceMinX, faceMaxY - faceMinY);
                CGRect imageRect = CGRectMake(rect.origin.x * scale, rect.origin.y * scale, rect.size.width * scale, rect.size.height * scale);
                
                CGImageRef image = CGImageCreateWithImageInRect(faceImage.CGImage, imageRect);
                faceImage = [UIImage imageWithCGImage:image];
                CGImageRelease(image);
                
                [facesImage addObject:faceImage];
                [facesRect addObject:[NSValue valueWithCGRect:rect]];
            }
        }
        
        for (int i = 0; i < facesImage.count; i ++) {
            UIImage *faceImage = facesImage[i];
            NSInteger nextIndex = (i + 1) % facesImage.count;
            CGRect faceRect = [facesRect[nextIndex] CGRectValue];
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:faceImage];
            imageView.frame = faceRect;
            [self.view addSubview:imageView];
            [self.faceImageViews addObject:imageView];
        }

    });
}

- (UIImage *)imageFromPixelBuffer:(CMSampleBufferRef) sampleBuffer {
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
