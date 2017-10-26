//
//  ChangeFaceViewController.m
//  VisionLearn
//
//  Created by hong-drmk on 2017/10/25.
//  Copyright © 2017年 Dasen. All rights reserved.
//

#import "ChangeFaceViewController.h"
#import "DSViewTool.h"
#import "DSVisionTool.h"
#import "DSDetectData.h"

@interface ChangeFaceViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIImageView *showImageView;
@property (nonatomic, strong) UIImagePickerController *pickerVc;

@end

@implementation ChangeFaceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.showImageView];
    self.view.backgroundColor = [UIColor whiteColor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self presentViewController:self.pickerVc animated:NO completion:nil];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [self.pickerVc dismissViewControllerAnimated:NO completion:nil];
    [self detectFace:info[UIImagePickerControllerOriginalImage]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self.pickerVc dismissViewControllerAnimated:YES completion:nil];
}

- (void)detectFace:(UIImage *)image{
    
    UIImage *localImage = [image scaleImage:SCREEN_WIDTH];
    [self.showImageView setImage:localImage];
    self.showImageView.size = localImage.size;
    
    [DSVisionTool detectImageWithType:DSDetectionTypeLandmark image:localImage complete:^(DSDetectData * _Nullable detectData) {
        
        UIImage *sourceImage = localImage;
        NSMutableArray <UIImage *>*facesImage = @[].mutableCopy;
        NSMutableArray <NSValue *>*facesRect = @[].mutableCopy;
        
        for (DSDetectFaceData *faceData in detectData.facePoints) {
            VNFaceLandmarkRegion2D *faceContour = faceData.faceContour;
            VNFaceLandmarkRegion2D *leftEyebrow = faceData.leftEyebrow;
            VNFaceLandmarkRegion2D *rightEyebrow = faceData.rightEyebrow;
            VNFaceObservation *observation = faceData.observation;
            CGFloat faceMinX = CGFLOAT_MAX;
            CGFloat faceMinY = CGFLOAT_MAX;
            CGFloat faceMaxX = CGFLOAT_MIN;
            CGFloat faceMaxY = CGFLOAT_MIN;
            NSInteger pointCount = faceContour.pointCount + leftEyebrow.pointCount + rightEyebrow.pointCount;
            CGPoint points[pointCount];
            
            //转换所有脸部轮廓特征点
            CGFloat rectWidth = observation.boundingBox.size.width * sourceImage.size.width;
            CGFloat rectHeight = observation.boundingBox.size.height * sourceImage.size.height;
            CGFloat rectX = observation.boundingBox.origin.x * sourceImage.size.width;
            CGFloat rectY = (1 - observation.boundingBox.origin.y) * sourceImage.size.height - rectHeight;
            
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
            UIGraphicsBeginImageContextWithOptions(sourceImage.size, NO, 0);
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
            
            CGRect rect = CGRectMake(0, 0, sourceImage.size.width, sourceImage.size.height);
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
                
                [facesImage addObject:faceImage];
                [facesRect addObject:[NSValue valueWithCGRect:rect]];
            }
        }
        
        //交换脸
        self.showImageView.image = [self getChangedFaceWithSourceImage:localImage
                                                            facesImage:facesImage
                                                             facesRect:facesRect];
    }];
}

- (UIImage *)getChangedFaceWithSourceImage:(UIImage *)sourceImage
                                facesImage:(NSArray <UIImage *>*)facesImage
                                 facesRect:(NSArray <NSValue *>*)facesRect {
    UIImage *resultImage = sourceImage;
    
    for (int i = 0; i < facesImage.count; i ++) {
        UIImage *faceImage = facesImage[i];
        NSInteger nextIndex = (i + 1) % facesImage.count;
        CGRect faceRect = [facesRect[nextIndex] CGRectValue];
        
        UIGraphicsBeginImageContextWithOptions(sourceImage.size, NO, 0);
        
        [resultImage drawInRect:CGRectMake(0, 0, sourceImage.size.width, sourceImage.size.height)];
        [faceImage drawInRect:faceRect];
        
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return resultImage;
}

#pragma mark 懒加载控件
- (UIImageView *)showImageView{
    if (!_showImageView) {
        _showImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 64, SCREEN_SIZE.width, SCREEN_SIZE.width)];
        _showImageView.contentMode = UIViewContentModeScaleAspectFit;
        _showImageView.backgroundColor = [UIColor orangeColor];
    }
    return _showImageView;
}

- (UIImagePickerController *)pickerVc
{
    if (!_pickerVc) {
        _pickerVc = [[UIImagePickerController alloc]init];
        _pickerVc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        _pickerVc.delegate = self;
    }
    return _pickerVc;
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
