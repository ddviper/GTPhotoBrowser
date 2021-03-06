//
//  GTPhotoActionSheet.m
//  GPUImage
//
//  Created by liuxc on 2018/6/30.
//

#import "GTPhotoActionSheet.h"
#import "GTCollectionCell.h"
#import "GTPhotoManager.h"
#import "GTImagePickerController.h"
#import "GTPhotoPreviewController.h"
#import "GTThumbnailViewController.h"
#import "GTNoAuthorityViewController.h"
#import "ToastUtils.h"
#import "GTEditViewController.h"
#import "GTEditVideoController.h"
#import "GTCustomCameraController.h"
#import "GTPhotoDefine.h"
#import "UIImage+GTPhotoBrowser.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define kBaseViewHeight (self.configuration.maxPreviewCount ? 300 : 142)

double const ScalePhotoWidth = 1000;

@interface GTPhotoActionSheet () <UICollectionViewDelegateFlowLayout, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPhotoLibraryChangeObserver>
{
    CGPoint _panBeginPoint;
    GTCollectionCell *_panCell;
    UIImageView *_panView;
    GTPhotoModel *_panModel;
}

@property (weak, nonatomic) IBOutlet UIButton *btnCamera;
@property (weak, nonatomic) IBOutlet UIButton *btnAblum;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (weak, nonatomic) IBOutlet UIView *baseView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *verColHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *verBottomSpace;


@property (nonatomic, assign) BOOL animate;
@property (nonatomic, assign) BOOL preview;

@property (nonatomic, strong) NSMutableArray<GTPhotoModel *> *arrDataSources;

@property (nonatomic, copy) NSMutableArray<GTPhotoModel *> *arrSelectedModels;

@property (nonatomic, assign) BOOL isSelectOriginalPhoto;
@property (nonatomic, assign) UIStatusBarStyle previousStatusBarStyle;
@property (nonatomic, assign) BOOL previousStatusBarIsHidden;
@property (nonatomic, assign) BOOL senderTabBarIsShow;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (assign, nonatomic) BOOL useCachedImage;


@end

@implementation GTPhotoActionSheet

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    //    NSLog(@"---- %s", __FUNCTION__);
}

- (NSMutableArray<GTPhotoModel *> *)arrDataSources
{
    if (!_arrDataSources) {
        _arrDataSources = [NSMutableArray array];
    }
    return _arrDataSources;
}

- (NSMutableArray<GTPhotoModel *> *)arrSelectedModels
{
    if (!_arrSelectedModels) {
        _arrSelectedModels = [NSMutableArray array];
    }
    return _arrSelectedModels;
}

- (UILabel *)placeholderLabel
{
    if (!_placeholderLabel) {
        _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kViewWidth, 100)];
        _placeholderLabel.text = GetLocalLanguageTextValue(GTPhotoBrowserNoPhotoText);
        _placeholderLabel.textAlignment = NSTextAlignmentCenter;
        _placeholderLabel.textColor = [UIColor darkGrayColor];
        _placeholderLabel.font = [UIFont systemFontOfSize:15];
        _placeholderLabel.center = self.collectionView.center;
        [self.collectionView addSubview:_placeholderLabel];
        _placeholderLabel.hidden = YES;
    }
    return _placeholderLabel;
}

#pragma mark - setter
- (void)setArrSelectedAssets:(NSMutableArray<PHAsset *> *)arrSelectedAssets
{
    _arrSelectedAssets = arrSelectedAssets;
    [self.arrSelectedModels removeAllObjects];
    for (PHAsset *asset in arrSelectedAssets) {
        GTPhotoModel *model = [GTPhotoModel modelWithAsset:asset type:[GTPhotoManager transformAssetType:asset] duration:nil];
        model.selected = YES;
        [self.arrSelectedModels addObject:model];
    }
}

- (instancetype)init
{
    self = [[kGTPhotoBrowserBundle loadNibNamed:@"GTPhotoActionSheet" owner:self options:nil] lastObject];
    if (self) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        layout.minimumInteritemSpacing = 3;
        layout.sectionInset = UIEdgeInsetsMake(0, 5, 0, 5);
        
        _configuration = [GTPhotoConfiguration defaultPhotoConfiguration];
        
        self.collectionView.collectionViewLayout = layout;
        self.collectionView.backgroundColor = [UIColor whiteColor];
        [self.collectionView registerClass:NSClassFromString(@"GTCollectionCell") forCellWithReuseIdentifier:@"GTCollectionCell"];
        if (![GTPhotoManager havePhotoLibraryAuthority]) {
            //注册实施监听相册变化
            [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
        }
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!self.configuration.allowSelectImage && self.configuration.allowRecordVideo) {
        [self.btnCamera setTitle:GetLocalLanguageTextValue(GTPhotoBrowserCameraRecordText) forState:UIControlStateNormal];
    } else {
        [self.btnCamera setTitle:GetLocalLanguageTextValue(GTPhotoBrowserCameraText) forState:UIControlStateNormal];
    }
    [self.btnAblum setTitle:GetLocalLanguageTextValue(GTPhotoBrowserAblumText) forState:UIControlStateNormal];
    [self.btnCancel setTitle:GetLocalLanguageTextValue(GTPhotoBrowserCancelText) forState:UIControlStateNormal];
    [self resetSubViewState];
}

//相册变化回调
- (void)photoLibraryDidChange:(PHChange *)changeInstance
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.preview) {
            [self loadPhotoFromAlbum];
            [self show];
        } else {
            [self btnPhotoLibrary_Click:nil];
        }
        [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    });
}

- (void)showPreviewAnimated:(BOOL)animate sender:(UIViewController *)sender
{
    self.sender = sender;
    [self showPreviewAnimated:animate];
}

- (void)showPreviewAnimated:(BOOL)animate
{
    [self showPreview:YES animate:animate];
}

- (void)showPhotoLibraryWithSender:(UIViewController *)sender
{
    self.sender = sender;
    [self showPhotoLibrary];
}

- (void)showPhotoLibrary
{
    [self showPreview:NO animate:NO];
}

- (void)showCameraWithSender:(UIViewController *)sender
{
    [self btnCamera_Click:sender];
}

- (void)showCamera
{
    [self btnCamera_Click:nil];
}

- (void)showPreview:(BOOL)preview animate:(BOOL)animate
{
    NSAssert(self.sender != nil, @"sender 对象不能为空");
    
    if (!self.configuration.allowSelectImage && self.arrSelectedModels.count) {
        [self.arrSelectedAssets removeAllObjects];
        [self.arrSelectedModels removeAllObjects];
    }
    
    self.animate = animate;
    self.preview = preview;
    self.previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
    self.previousStatusBarIsHidden = [UIApplication sharedApplication].isStatusBarHidden;
    
    [GTPhotoManager setSortAscending:self.configuration.sortAscending];
    
    if (!self.configuration.maxPreviewCount) {
        self.verColHeight.constant = .0;
    } else if (self.configuration.allowDragSelect) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panAction:)];
        [self.baseView addGestureRecognizer:pan];
    }
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusRestricted ||
        status == PHAuthorizationStatusDenied) {
        [self showNoAuthorityVC];
        return;
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            
        }];
        
        [self.sender.view addSubview:self];
    }
    
    if (preview) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self loadPhotoFromAlbum];
            [self show];
        }
    } else {
        if (status == PHAuthorizationStatusAuthorized) {
            [self.sender.view addSubview:self];
            [self btnPhotoLibrary_Click:nil];
        }
    }
}

- (void)previewSelectedPhotos:(NSArray<UIImage *> *)photos assets:(NSArray<PHAsset *> *)assets index:(NSInteger)index isOriginal:(BOOL)isOriginal
{
    self.isSelectOriginalPhoto = isOriginal;
    //将assets转换为对应类型的model
    NSMutableArray<GTPhotoModel *> *models = [NSMutableArray arrayWithCapacity:assets.count];
    for (PHAsset *asset in assets) {
        GTPhotoModel *model = [GTPhotoModel modelWithAsset:asset type:[GTPhotoManager transformAssetType:asset] duration:nil];
        model.selected = YES;
        [models addObject:model];
    }
    GTPhotoPreviewController *svc = [self pushBigImageToPreview:photos models:models index:index];
    
    gt_weakify(self);
    __weak typeof(svc.navigationController) weakNav = svc.navigationController;
    svc.previewSelectedImageBlock = ^(NSArray<UIImage *> *arrP, NSArray<PHAsset *> *arrA) {
        gt_strongify(weakSelf);
        strongSelf.arrSelectedAssets = assets.mutableCopy;
        __strong typeof(weakNav) strongNav = weakNav;
        if (strongSelf.selectImageBlock) {
            strongSelf.selectImageBlock(arrP, arrA, NO);
        }
        [strongSelf hide];
        [strongNav dismissViewControllerAnimated:YES completion:nil];
    };
    
    svc.cancelPreviewBlock = ^{
        gt_strongify(weakSelf);
        [strongSelf hide];
    };
}

- (void)previewPhotos:(NSArray<NSDictionary *> *)photos index:(NSInteger)index hideToolBar:(BOOL)hideToolBar complete:(void (^)(NSArray * _Nonnull))complete
{
    //转换为对应类型的model对象
    NSMutableArray<GTPhotoModel *> *models = [NSMutableArray arrayWithCapacity:photos.count];
    for (NSDictionary *dic in photos) {
        GTPhotoModel *model = [[GTPhotoModel alloc] init];
        GTPreviewPhotoType type = [dic[GTPreviewPhotoTyp] integerValue];
        id obj = dic[GTPreviewPhotoObj];
        switch (type) {
            case GTPreviewPhotoTypePHAsset:
                model.asset = obj;
                model.type = [GTPhotoManager transformAssetType:obj];
                break;
            case GTPreviewPhotoTypeUIImage:
                model.image = obj;
                model.type = GTAssetMediaTypeNetImage;
                break;
            case GTPreviewPhotoTypeURLImage:
                model.url = obj;
                model.type = GTAssetMediaTypeNetImage;
                break;
            case GTPreviewPhotoTypeURLVideo:
                model.url = obj;
                model.type = GTAssetMediaTypeNetVideo;
                break;
        }
        model.selected = YES;
        [models addObject:model];
    }
    GTPhotoPreviewController *svc = [self pushBigImageToPreview:photos models:models index:index];
    svc.hideToolBar = hideToolBar;
    
    gt_weakify(self);
    __weak typeof(svc.navigationController) weakNav = svc.navigationController;
    [svc setPreviewNetImageBlock:^(NSArray *photos) {
        gt_strongify(weakSelf);
        __strong typeof(weakNav) strongNav = weakNav;
        if (complete) complete(photos);
        [strongSelf hide];
        [strongNav dismissViewControllerAnimated:YES completion:nil];
    }];
    svc.cancelPreviewBlock = ^{
        gt_strongify(weakSelf);
        [strongSelf hide];
    };
}

- (void)loadPhotoFromAlbum
{
    [self.arrDataSources removeAllObjects];
    
    [self.arrDataSources addObjectsFromArray:[GTPhotoManager getAllAssetInPhotoAlbumWithAscending:NO limitCount:self.configuration.maxPreviewCount allowSelectVideo:self.configuration.allowSelectVideo allowSelectImage:self.configuration.allowSelectImage allowSelectGif:self.configuration.allowSelectGif allowSelectLivePhoto:self.configuration.allowSelectLivePhoto]];
    [GTPhotoManager markSelectModelInArr:self.arrDataSources selArr:self.arrSelectedModels];
    [self.collectionView reloadData];
}

#pragma mark - 显示隐藏视图及相关动画
- (void)resetSubViewState
{
    self.hidden = ![GTPhotoManager havePhotoLibraryAuthority] || !self.preview;
    [self changeCancelBtnTitle];
    //    [self.collectionView setContentOffset:CGPointZero];
}

- (void)show
{
    self.frame = self.sender.view.bounds;
    [self.collectionView setContentOffset:CGPointZero];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (!self.superview) {
        [self.sender.view addSubview:self];
    }
    
    if (self.sender.tabBarController.tabBar && self.sender.tabBarController.tabBar.hidden == NO) {
        self.senderTabBarIsShow = YES;
        self.sender.tabBarController.tabBar.hidden = YES;
    }
    
    UIEdgeInsets inset = UIEdgeInsetsZero;
    if (@available(iOS 11, *)) {
        double flag = .0;
        if (self.senderTabBarIsShow) {
            flag = 49;
        }
        inset = self.sender.view.safeAreaInsets;
        inset.bottom -= flag;
        [self.verBottomSpace setConstant:inset.bottom];
    }
    if (self.animate) {
        __block CGRect frame = self.baseView.frame;
        frame.origin.y = kViewHeight;
        self.baseView.frame = frame;
        [UIView animateWithDuration:0.2 animations:^{
            frame.origin.y -= kBaseViewHeight;
            self.baseView.frame = frame;
        } completion:nil];
    }
}

- (void)hide
{
    if (self.animate) {
        UIEdgeInsets inset = UIEdgeInsetsZero;
        if (@available(iOS 11, *)) {
            inset = self.sender.view.safeAreaInsets;
        }
        __block CGRect frame = self.baseView.frame;
        frame.origin.y += (kBaseViewHeight+inset.bottom);
        [UIView animateWithDuration:0.2 animations:^{
            self.baseView.frame = frame;
        } completion:^(BOOL finished) {
            self.hidden = YES;
            [UIApplication sharedApplication].statusBarHidden = self.previousStatusBarIsHidden;
            [self removeFromSuperview];
        }];
    } else {
        self.hidden = YES;
        [UIApplication sharedApplication].statusBarHidden = self.previousStatusBarIsHidden;
        [self removeFromSuperview];
    }
    if (self.senderTabBarIsShow) {
        self.sender.tabBarController.tabBar.hidden = NO;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self hide];
}

- (void)panAction:(UIPanGestureRecognizer *)pan
{
    CGPoint point = [pan locationInView:self.baseView];
    if (pan.state == UIGestureRecognizerStateBegan) {
        if (!CGRectContainsPoint(self.collectionView.frame, point)) {
            _panBeginPoint = CGPointZero;
            return;
        }
        _panBeginPoint = [pan locationInView:self.collectionView];
        
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        if (CGPointEqualToPoint(_panBeginPoint, CGPointZero)) return;
        
        CGPoint cp = [pan locationInView:self.collectionView];
        
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:_panBeginPoint];
        
        if (!indexPath) return;
        
        if (!_panView) {
            if (cp.y > _panBeginPoint.y) {
                _panBeginPoint = CGPointZero;
                return;
            }
            
            _panModel = self.arrDataSources[indexPath.row];
            
            GTCollectionCell *cell = (GTCollectionCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            _panCell = cell;
            _panView = [[UIImageView alloc] initWithFrame:cell.bounds];
            _panView.image = cell.imageView.image;
            
            cell.imageView.image = nil;
            
            [self addSubview:_panView];
        }
        
        _panView.center = [self convertPoint:point fromView:self.baseView];
    } else if (pan.state == UIGestureRecognizerStateCancelled ||
               pan.state == UIGestureRecognizerStateEnded) {
        if (!_panView) return;
        
        CGRect panViewRect = [self.baseView convertRect:_panView.frame fromView:self];
        BOOL callBack = NO;
        if (CGRectGetMidY(panViewRect) < -10) {
            //如果往上拖动距离中心点与collectionview间距大于10，则回调
            [self requestSelPhotos:nil data:@[_panModel] hideAfterCallBack:NO];
            callBack = YES;
        }
        
        _panModel = nil;
        if (!callBack) {
            CGRect toRect = [self convertRect:_panCell.frame fromView:self.collectionView];
            [UIView animateWithDuration:0.25 animations:^{
                _panView.frame = toRect;
            } completion:^(BOOL finished) {
                _panCell.imageView.image = _panView.image;
                _panCell = nil;
                [_panView removeFromSuperview];
                _panView = nil;
            }];
        } else {
            _panCell.imageView.image = _panView.image;
            _panCell.imageView.frame = CGRectZero;
            _panCell.imageView.center = _panCell.contentView.center;
            [_panView removeFromSuperview];
            _panView = nil;
            [UIView animateWithDuration:0.25 animations:^{
                _panCell.imageView.frame = _panCell.contentView.frame;
            } completion:^(BOOL finished) {
                _panCell = nil;
            }];
        }
    }
}

- (NSInteger)getIndexWithSelectArrayWithModel:(GTPhotoModel *)model
{
    NSInteger index = 0;
    for (NSInteger i = 0; i < self.arrSelectedModels.count; i++) {
        if ([model.asset.localIdentifier isEqualToString:self.arrSelectedModels[i].asset.localIdentifier]) {
            index = i + 1;
            break;
        }
    }
    return index;
}

- (void)setUseCachedImageAndReloadData {
    self.useCachedImage = YES;
    [self.collectionView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.useCachedImage = NO;
    });
}

#pragma mark - UIButton Action
- (IBAction)btnCamera_Click:(id)sender
{
    if (![GTPhotoManager haveCameraAuthority]) {
        NSString *message = [NSString stringWithFormat:GetLocalLanguageTextValue(GTPhotoBrowserNoCameraAuthorityText), kAPPName];
        ShowAlert(message, self.sender);
        [self hide];
        return;
    }
    if (!self.configuration.allowSelectImage &&
        !self.configuration.allowRecordVideo) {
        ShowAlert(@"allowSelectImage与allowRecordVideo不能同时为NO", self.sender);
        return;
    }
    if (self.configuration.useSystemCamera) {
        //系统相机拍照
        if ([UIImagePickerController isSourceTypeAvailable:
             UIImagePickerControllerSourceTypeCamera]){
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.delegate = self;
            picker.allowsEditing = NO;
            picker.videoQuality = UIImagePickerControllerQualityTypeHigh;
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            NSArray *a1 = self.configuration.allowSelectImage?@[(NSString *)kUTTypeImage]:@[];
            NSArray *a2 = (self.configuration.allowSelectVideo && self.configuration.allowRecordVideo)?@[(NSString *)kUTTypeMovie]:@[];
            NSMutableArray *arr = [NSMutableArray array];
            [arr addObjectsFromArray:a1];
            [arr addObjectsFromArray:a2];
            
            picker.mediaTypes = arr;
            picker.videoMaximumDuration = self.configuration.maxRecordDuration;
            [self.sender showDetailViewController:picker sender:nil];
        }
    } else {
        if (![GTPhotoManager haveMicrophoneAuthority]) {
            NSString *message = [NSString stringWithFormat:GetLocalLanguageTextValue(GTPhotoBrowserNoMicrophoneAuthorityText), kAPPName];
            ShowAlert(message, self.sender);
            [self hide];
            return;
        }
        GTCustomCameraController *camera = [[GTCustomCameraController alloc] init];
        camera.allowTakePhoto = self.configuration.allowSelectImage;
        camera.allowRecordVideo = self.configuration.allowSelectVideo && self.configuration.allowRecordVideo;
        camera.sessionPreset = self.configuration.sessionPreset;
        camera.videoType = self.configuration.exportVideoType;
        camera.circleProgressColor = self.configuration.bottomBtnsNormalTitleColor;
        camera.maxRecordDuration = self.configuration.maxRecordDuration;
        gt_weakify(self);
        camera.doneBlock = ^(UIImage *image, NSURL *videoUrl) {
            gt_strongify(weakSelf);
            [strongSelf saveImage:image videoUrl:videoUrl];
        };
        [self.sender showDetailViewController:camera sender:nil];
    }
}

- (IBAction)btnPhotoLibrary_Click:(id)sender
{
    if (![GTPhotoManager havePhotoLibraryAuthority]) {
        [self showNoAuthorityVC];
    } else {
        self.animate = NO;
        [self pushThumbnailViewController];
    }
}

- (IBAction)btnCancel_Click:(id)sender
{
    if (self.arrSelectedModels.count) {
        [self requestSelPhotos:nil data:self.arrSelectedModels hideAfterCallBack:YES];
        return;
    }
    
    if (self.cancleBlock) self.cancleBlock();
    [self hide];
}

- (void)changeCancelBtnTitle
{
    if (self.arrSelectedModels.count > 0) {
        [self.btnCancel setTitle:[NSString stringWithFormat:@"%@(%ld)", GetLocalLanguageTextValue(GTPhotoBrowserDoneText), (unsigned long)self.arrSelectedModels.count] forState:UIControlStateNormal];
        [self.btnCancel setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    } else {
        [self.btnCancel setTitle:GetLocalLanguageTextValue(GTPhotoBrowserCancelText) forState:UIControlStateNormal];
        [self.btnCancel setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    }
}

#pragma mark - 请求所选择图片、回调
- (void)requestSelPhotos:(UIViewController *)vc data:(NSArray<GTPhotoModel *> *)data hideAfterCallBack:(BOOL)hide
{
    GTProgressHUD *hud = [[GTProgressHUD alloc] init];
    [hud show];
    
    if (!self.configuration.shouldAnialysisAsset) {
        NSMutableArray *assets = [NSMutableArray arrayWithCapacity:data.count];
        for (GTPhotoModel *m in data) {
            [assets addObject:m.asset];
        }
        [hud hide];
        if (self.selectImageBlock) {
            self.selectImageBlock(nil, assets, self.isSelectOriginalPhoto);
            [self.arrSelectedModels removeAllObjects];
        }
        if (hide) {
            [self hide];
            [vc dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }
    
    __block NSMutableArray *photos = [NSMutableArray arrayWithCapacity:data.count];
    __block NSMutableArray *assets = [NSMutableArray arrayWithCapacity:data.count];
    for (int i = 0; i < data.count; i++) {
        [photos addObject:@""];
        [assets addObject:@""];
    }
    
    gt_weakify(self);
    for (int i = 0; i < data.count; i++) {
        GTPhotoModel *model = data[i];
        [GTPhotoManager requestSelectedImageForAsset:model isOriginal:self.isSelectOriginalPhoto allowSelectGif:self.configuration.allowSelectGif completion:^(UIImage *image, NSDictionary *info) {
            if ([[info objectForKey:PHImageResultIsDegradedKey] boolValue]) return;
            
            gt_strongify(weakSelf);
            if (image) {
                [photos replaceObjectAtIndex:i withObject:[GTPhotoManager scaleImage:image original:strongSelf->_isSelectOriginalPhoto]];
                [assets replaceObjectAtIndex:i withObject:model.asset];
            }
            
            for (id obj in photos) {
                if ([obj isKindOfClass:[NSString class]]) return;
            }
            
            [hud hide];
            if (strongSelf.selectImageBlock) {
                strongSelf.selectImageBlock(photos, assets, strongSelf.isSelectOriginalPhoto);
                [strongSelf.arrSelectedModels removeAllObjects];
            }
            if (hide) {
                [strongSelf.arrDataSources removeAllObjects];
                [strongSelf hide];
                [vc dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    }
}

#pragma mark - UICollectionDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (self.arrDataSources.count == 0) {
        self.placeholderLabel.hidden = NO;
    } else {
        self.placeholderLabel.hidden = YES;
    }
    return self.arrDataSources.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    GTCollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"GTCollectionCell" forIndexPath:indexPath];

    cell.photoSelImage = self.configuration.showSelectedIndex ? [UIImage createImageWithColor:nil size:CGSizeMake(24, 24) radius:12] : GetImageWithName(@"gt_btn_selected");
    cell.photoDefImage = GetImageWithName(@"gt_btn_unselected");
    cell.useCachedImage = self.useCachedImage;
    
    GTPhotoModel *model = self.arrDataSources[indexPath.row];

    cell.allSelectGif = self.configuration.allowSelectGif;
    cell.allSelectLivePhoto = self.configuration.allowSelectLivePhoto;
    cell.showSelectBtn = self.configuration.showSelectBtn;
    cell.cornerRadio = self.configuration.cellCornerRadio;
    cell.showMask = self.configuration.showSelectedMask;
    cell.maskColor = self.configuration.selectedMaskColor;
    cell.showSelectedIndex = self.configuration.showSelectedIndex;
    cell.showPhotoCannotSelectLayer = self.configuration.showPhotoCannotSelectLayer;
    cell.cannotSelectLayerColor = self.configuration.cannotSelectLayerColor;
    cell.model = model;

    if (self.configuration.showSelectedIndex) {
        cell.index = [self getIndexWithSelectArrayWithModel:model];
    }

    if (self.arrSelectedModels.count >= self.configuration.maxSelectCount && self.configuration.showPhotoCannotSelectLayer && !model.isSelected) {
        cell.cannotSelectLayerButton.backgroundColor = self.configuration.cannotSelectLayerColor;
        cell.cannotSelectLayerButton.hidden = NO;
    } else {
        cell.cannotSelectLayerButton.hidden = YES;
    }
    
    gt_weakify(self);
    __weak typeof(cell) weakCell = cell;
    cell.selectedBlock = ^(BOOL selected) {
        gt_strongify(weakSelf);
        __strong typeof(weakCell) strongCell = weakCell;
        if (!selected) {
            //选中
            if (strongSelf.arrSelectedModels.count >= strongSelf.configuration.maxSelectCount) {
                ShowToastLong(GetLocalLanguageTextValue(GTPhotoBrowserMaxSelectCountText), strongSelf.configuration.maxSelectCount);
                return;
            }
            if (strongSelf.arrSelectedModels.count > 0) {
                GTPhotoModel *sm = strongSelf.arrSelectedModels.firstObject;
                if (!strongSelf.configuration.allowMixSelect &&
                    ((model.type < GTAssetMediaTypeVideo && sm.type == GTAssetMediaTypeVideo) || (model.type == GTAssetMediaTypeVideo && sm.type < GTAssetMediaTypeVideo))) {
                    ShowToastLong(@"%@", GetLocalLanguageTextValue(GTPhotoBrowserCannotSelectVideo));
                    return;
                }
            }
            if (![GTPhotoManager judgeAssetisInLocalAblum:model.asset]) {
                ShowToastLong(@"%@", GetLocalLanguageTextValue(GTPhotoBrowseriCloudPhotoText));
                return;
            }
            if (model.type == GTAssetMediaTypeVideo && GetDuration(model.duration) > strongSelf.configuration.maxVideoDuration) {
                ShowToastLong(GetLocalLanguageTextValue(GTPhotoBrowserMaxVideoDurationText), strongSelf.configuration.maxVideoDuration);
                return;
            }
            
            if (![strongSelf shouldDirectEdit:model]) {
                model.selected = YES;
                strongCell.selectImageView.image = strongCell.photoSelImage;
                [strongSelf.arrSelectedModels addObject:model];
                strongCell.btnSelect.selected = YES;
            }
        } else {
            strongCell.btnSelect.selected = NO;
            strongCell.selectImageView.image = strongCell.photoDefImage;
            model.selected = NO;
            for (GTPhotoModel *m in strongSelf.arrSelectedModels) {
                if ([m.asset.localIdentifier isEqualToString:model.asset.localIdentifier]) {
                    [strongSelf.arrSelectedModels removeObject:m];
                    break;
                }
            }
        }
        
        if (strongSelf.configuration.showSelectedMask) {
            strongCell.topView.hidden = !model.isSelected;
        }
        if (strongSelf.configuration.showSelectedIndex) {
            strongCell.index = [self getIndexWithSelectArrayWithModel:model];
        }
        if (strongSelf.configuration.showPhotoCannotSelectLayer || strongSelf.configuration.showSelectedIndex) {
            model.needOscillatoryAnimation = YES;
            [strongSelf setUseCachedImageAndReloadData];
        }
        [strongSelf changeCancelBtnTitle];
    };

    return cell;
}

#pragma mark - UICollectionViewDelegate
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    GTPhotoModel *model = self.arrDataSources[indexPath.row];
    return [self getSizeWithAsset:model.asset];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    GTPhotoModel *model = self.arrDataSources[indexPath.row];
    
    if ([self shouldDirectEdit:model]) return;
    
    if (self.arrSelectedModels.count > 0) {
        GTPhotoModel *sm = self.arrSelectedModels.firstObject;
        if (!self.configuration.allowMixSelect &&
            ((model.type < GTAssetMediaTypeVideo && sm.type == GTAssetMediaTypeVideo) || (model.type == GTAssetMediaTypeVideo && sm.type < GTAssetMediaTypeVideo))) {
            ShowToastLong(@"%@", GetLocalLanguageTextValue(GTPhotoBrowserCannotSelectVideo));
            return;
        }
    }
    
    BOOL allowSelImage = !(model.type==GTAssetMediaTypeVideo)?YES:self.configuration.allowMixSelect;
    BOOL allowSelVideo = model.type==GTAssetMediaTypeVideo?YES:self.configuration.allowMixSelect;
    
    NSArray *arr = [GTPhotoManager getAllAssetInPhotoAlbumWithAscending:self.configuration.sortAscending limitCount:NSIntegerMax allowSelectVideo:allowSelVideo allowSelectImage:allowSelImage allowSelectGif:self.configuration.allowSelectGif allowSelectLivePhoto:self.configuration.allowSelectLivePhoto];
    
    NSMutableArray *selIdentifiers = [NSMutableArray array];
    for (GTPhotoModel *m in self.arrSelectedModels) {
        [selIdentifiers addObject:m.asset.localIdentifier];
    }
    
    int i = 0;
    BOOL isFind = NO;
    for (GTPhotoModel *m in arr) {
        if ([m.asset.localIdentifier isEqualToString:model.asset.localIdentifier]) {
            isFind = YES;
        }
        if ([selIdentifiers containsObject:m.asset.localIdentifier]) {
            m.selected = YES;
        }
        if (!isFind) {
            i++;
        }
    }
    
    [self pushBigImageViewControllerWithModels:arr index:i];
}

- (BOOL)shouldDirectEdit:(GTPhotoModel *)model
{
    //当前点击图片可编辑
    BOOL editImage = self.configuration.editAfterSelectThumbnailImage && self.configuration.allowEditImage && self.configuration.maxSelectCount == 1 && model.type < GTAssetMediaTypeVideo;
    //当前点击视频可编辑
    BOOL editVideo = self.configuration.editAfterSelectThumbnailImage && self.configuration.allowEditVideo && model.type == GTAssetMediaTypeVideo && self.configuration.maxSelectCount == 1 && round(model.asset.duration) >= self.configuration.maxEditVideoTime;
    //当前未选择图片 或已经选择了一张并且点击的是已选择的图片
    BOOL flag = self.arrSelectedModels.count == 0 || (self.arrSelectedModels.count == 1 && [self.arrSelectedModels.firstObject.asset.localIdentifier isEqualToString:model.asset.localIdentifier]);
    
    if (editImage && flag) {
        [self pushEditVCWithModel:model];
    } else if (editVideo && flag) {
        [self pushEditVideoVCWithModel:model];
    }
    
    return self.configuration.editAfterSelectThumbnailImage && self.configuration.maxSelectCount == 1 && (self.configuration.allowEditImage || self.configuration.allowEditVideo);
}

#pragma mark - 显示无权限视图
- (void)showNoAuthorityVC
{
    //无相册访问权限
    GTNoAuthorityViewController *nvc = [[GTNoAuthorityViewController alloc] init];
    [self.sender showDetailViewController:[self getImageNavWithRootVC:nvc] sender:nil];
}

- (GTImagePickerController *)getImageNavWithRootVC:(UIViewController *)rootVC
{
    GTImagePickerController *nav = [[GTImagePickerController alloc] initWithRootViewController:rootVC];
    gt_weakify(self);
    __weak typeof(GTImagePickerController *) weakNav = nav;
    [nav setCallSelectImageBlock:^{
        gt_strongify(weakSelf);
        strongSelf.isSelectOriginalPhoto = weakNav.isSelectOriginalPhoto;
        [strongSelf.arrSelectedModels removeAllObjects];
        [strongSelf.arrSelectedModels addObjectsFromArray:weakNav.arrSelectedModels];
        [strongSelf requestSelPhotos:weakNav data:strongSelf.arrSelectedModels hideAfterCallBack:YES];
    }];
    
    [nav setCallSelectClipImageBlock:^(UIImage *image, PHAsset *asset){
        gt_strongify(weakSelf);
        if (strongSelf.selectImageBlock) {
            strongSelf.selectImageBlock(@[image], @[asset], NO);
        }
        [weakNav dismissViewControllerAnimated:YES completion:nil];
        [strongSelf hide];
    }];
    
    [nav setCancelBlock:^{
        gt_strongify(weakSelf);
        if (strongSelf.cancleBlock) strongSelf.cancleBlock();
        [strongSelf hide];
    }];
    
    nav.isSelectOriginalPhoto = self.isSelectOriginalPhoto;
    nav.previousStatusBarStyle = self.previousStatusBarStyle;
    nav.configuration = self.configuration;
    [nav.arrSelectedModels removeAllObjects];
    [nav.arrSelectedModels addObjectsFromArray:self.arrSelectedModels];
    
    return nav;
}

//预览界面
- (void)pushThumbnailViewController
{
    GTAlbumPickerController *albumPicker = [[GTAlbumPickerController alloc] initWithStyle:UITableViewStylePlain];
    GTImagePickerController *nav = [self getImageNavWithRootVC:albumPicker];
    GTThumbnailViewController *tvc = [[GTThumbnailViewController alloc] init];
    [nav pushViewController:tvc animated:YES];
    [self.sender showDetailViewController:nav sender:nil];
}

//查看大图界面
- (void)pushBigImageViewControllerWithModels:(NSArray<GTPhotoModel *> *)models index:(NSInteger)index
{
    GTPhotoPreviewController *svc = [[GTPhotoPreviewController alloc] init];
    GTImagePickerController *nav = [self getImageNavWithRootVC:svc];
    
    svc.models = models;
    svc.selectIndex = index;
    gt_weakify(self);
    [svc setBtnBackBlock:^(NSArray<GTPhotoModel *> *selectedModels, BOOL isOriginal) {
        gt_strongify(weakSelf);
        [GTPhotoManager markSelectModelInArr:strongSelf.arrDataSources selArr:selectedModels];
        strongSelf.isSelectOriginalPhoto = isOriginal;
        [strongSelf.arrSelectedModels removeAllObjects];
        [strongSelf.arrSelectedModels addObjectsFromArray:selectedModels];
        [strongSelf.collectionView reloadData];
        [strongSelf changeCancelBtnTitle];
    }];
    
    [self.sender showDetailViewController:nav sender:nil];
}

- (GTPhotoPreviewController *)pushBigImageToPreview:(NSArray *)photos models:(NSArray<GTPhotoModel *> *)models index:(NSInteger)index
{
    GTPhotoPreviewController *svc = [[GTPhotoPreviewController alloc] init];
    GTImagePickerController *nav = [self getImageNavWithRootVC:svc];
    svc.selectIndex = index;
    svc.arrSelPhotos = [NSMutableArray arrayWithArray:photos];
    svc.models = models;
    
    self.preview = NO;
    [self.sender.view addSubview:self];
    [self.sender showDetailViewController:nav sender:nil];
    
    return svc;
}

- (void)pushEditVCWithModel:(GTPhotoModel *)model
{
    GTEditViewController *vc = [[GTEditViewController alloc] init];
    GTImagePickerController *nav = [self getImageNavWithRootVC:vc];
    [nav.arrSelectedModels addObject:model];
    vc.model = model;
    [self.sender showDetailViewController:nav sender:nil];
}

- (void)pushEditVideoVCWithModel:(GTPhotoModel *)model
{
    GTEditVideoController *vc = [[GTEditVideoController alloc] init];
    GTImagePickerController *nav = [self getImageNavWithRootVC:vc];
    [nav.arrSelectedModels addObject:model];
    vc.model = model;
    [self.sender showDetailViewController:nav sender:nil];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:^{
        UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
        NSURL *url = [info valueForKey:UIImagePickerControllerMediaURL];
        [self saveImage:image videoUrl:url];
    }];
}

- (void)saveImage:(UIImage *)image videoUrl:(NSURL *)videoUrl
{
    GTProgressHUD *hud = [[GTProgressHUD alloc] init];
    [hud show];
    gt_weakify(self);
    if (image) {
        [GTPhotoManager saveImageToAblum:image completion:^(BOOL suc, PHAsset *asset) {
            gt_strongify(weakSelf);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (suc) {
                    GTPhotoModel *model = [GTPhotoModel modelWithAsset:asset type:GTAssetMediaTypeImage duration:nil];
                    [strongSelf handleDataArray:model];
                } else {
                    ShowToastLong(@"%@", GetLocalLanguageTextValue(GTPhotoBrowserSaveImageErrorText));
                }
                [hud hide];
            });
        }];
    } else if (videoUrl) {
        [GTPhotoManager saveVideoToAblum:videoUrl completion:^(BOOL suc, PHAsset *asset) {
            gt_strongify(weakSelf);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (suc) {
                    GTPhotoModel *model = [GTPhotoModel modelWithAsset:asset type:GTAssetMediaTypeVideo duration:nil];
                    model.duration = [GTPhotoManager getDuration:asset];
                    [strongSelf handleDataArray:model];
                } else {
                    ShowToastLong(@"%@", GetLocalLanguageTextValue(GTPhotoBrowserSaveVideoFailed));
                }
                [hud hide];
            });
        }];
    }
}

- (void)handleDataArray:(GTPhotoModel *)model
{
    gt_weakify(self);
    BOOL (^shouldSelect)(void) = ^BOOL() {
        gt_strongify(weakSelf);
        if (model.type == GTAssetMediaTypeVideo) {
            return (model.asset.duration <= strongSelf.configuration.maxVideoDuration);
        }
        return YES;
    };
    
    [self.arrDataSources insertObject:model atIndex:0];
    if (self.arrDataSources.count > self.configuration.maxPreviewCount) {
        [self.arrDataSources removeLastObject];
    }
    BOOL sel = shouldSelect();
    if (self.configuration.maxSelectCount > 1 && self.arrSelectedModels.count < self.configuration.maxSelectCount && sel) {
        model.selected = sel;
        [self.arrSelectedModels addObject:model];
    } else if (self.configuration.maxSelectCount == 1 && !self.arrSelectedModels.count && sel) {
        if (![self shouldDirectEdit:model]) {
            model.selected = sel;
            [self.arrSelectedModels addObject:model];
            [self requestSelPhotos:nil data:self.arrSelectedModels hideAfterCallBack:YES];
            return;
        }
    }
    [self.collectionView reloadData];
    [self changeCancelBtnTitle];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 获取图片及图片尺寸的相关方法
- (CGSize)getSizeWithAsset:(PHAsset *)asset
{
    CGFloat width  = (CGFloat)asset.pixelWidth;
    CGFloat height = (CGFloat)asset.pixelHeight;
    CGFloat scale = MIN(1.7, MAX(0.5, width/height));
    
    return CGSizeMake(self.collectionView.frame.size.height*scale, self.collectionView.frame.size.height);
}

@end

