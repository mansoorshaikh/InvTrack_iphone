//
//  igViewController.h
//  ScanBarCodes
//
//  Created by Torrey Betts on 10/10/13.
//  Copyright (c) 2013 Infragistics. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreLocation/CoreLocation.h>
#import "Alertview/CustomIOS7AlertView.h"

@interface igViewController : UIViewController<CLLocationManagerDelegate,UIAlertViewDelegate,UITextViewDelegate>
@property(nonatomic,retain) CLLocationManager *locationManager;
@property(nonatomic,retain) CLLocation *currentLocation;
@property(nonatomic,retain) NSString *CommentStr,*hmacValue,*qrcode;
@property(nonatomic,retain) IBOutlet UIButton *upDateBtn,*cancelBtn;
@property(nonatomic,retain) CustomIOS7AlertView *alertView,*alertViewShow;
@property(nonatomic,retain) IBOutlet UITextView *CommentTxt;
@property(nonatomic,retain) NSString *udid;
@property(nonatomic,retain) IBOutlet UIActivityIndicatorView *activityIndicator;

@end