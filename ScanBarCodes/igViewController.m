//
//  igViewController.m
//  ScanBarCodes
//
//  Created by Torrey Betts on 10/10/13.
//  Copyright (c) 2013 Infragistics. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "igViewController.h"
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>
#import "UIDevice+IdentifierAddition.h"
#import <AdSupport/AdSupport.h>

@interface igViewController () <AVCaptureMetadataOutputObjectsDelegate,MFMessageComposeViewControllerDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_input;
    AVCaptureMetadataOutput *_output;
    AVCaptureVideoPreviewLayer *_prevLayer;
    
    UIView *_highlightView;
    UILabel *_label;
    
}
@property(nonatomic,readwrite) BOOL shouldSendReadBarcodeToDelegate;
@property(nonatomic) double oldlat;
@property(nonatomic) double oldlong;
@end

@implementation igViewController
@synthesize shouldSendReadBarcodeToDelegate,locationManager,oldlat,oldlong,upDateBtn,cancelBtn,alertView,CommentTxt,CommentStr,alertViewShow,hmacValue,qrcode,udid,activityIndicator;

-(void)viewDidAppear:(BOOL)animated{
    shouldSendReadBarcodeToDelegate=YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
       shouldSendReadBarcodeToDelegate=YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *newLocation=[locations lastObject];
    oldlat=newLocation.coordinate.latitude;
    oldlong=newLocation.coordinate.longitude;
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void) threadStartAnimating:(id)data {
    [activityIndicator startAnimating];
    activityIndicator.center = CGPointMake(self.view.frame.size.width / 2.0, self.view.frame.size.height / 2.0);
    [self.view addSubview: activityIndicator];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicator.center = CGPointMake(self.view.frame.size.width / 2.0, self.view.frame.size.height / 2.0); // I do this because I'm in landscape mode
    [self.view addSubview:activityIndicator];
    udid = [[UIDevice currentDevice] performSelector:@selector(uniqueIdentifier)];
    
    self.locationManager = [[CLLocationManager alloc] init];
    
    self.locationManager.delegate = self;
    if([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]){
        NSUInteger code = [CLLocationManager authorizationStatus];
        if (code == kCLAuthorizationStatusNotDetermined && ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)] || [self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])) {
            // choose one request according to your business.
            if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"]){
                [self.locationManager requestAlwaysAuthorization];
            } else if([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"]) {
                [self.locationManager  requestWhenInUseAuthorization];
            } else {
                NSLog(@"Info.plist does not contain NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription");
            }
        }
    }
    [self.locationManager startUpdatingLocation];
    
    _highlightView = [[UIView alloc] init];
    _highlightView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleBottomMargin;
    _highlightView.layer.borderColor = [UIColor greenColor].CGColor;
    _highlightView.layer.borderWidth = 3;
    [self.view addSubview:_highlightView];

    _label = [[UILabel alloc] init];
    _label.frame = CGRectMake(0, self.view.bounds.size.height - 40, self.view.bounds.size.width, 40);
    _label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _label.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.65];
    _label.textColor = [UIColor whiteColor];
    _label.textAlignment = NSTextAlignmentCenter;
    _label.text = @"(none)";
  //  [self.view addSubview:_label];
    
    UIImageView *logoImage=[[UIImageView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 100, 100, 100)];
    [logoImage setImage:[UIImage imageNamed:@"h2otrack_logo.png"]];
    [self.view addSubview:logoImage];
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;

    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }

    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];

    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];

    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];

    [_session startRunning];

    [self.view bringSubviewToFront:_highlightView];
    [self.view bringSubviewToFront:logoImage];
    
}


- (NSString *)hmacsha1:(NSString *)data secret:(NSString *)key {
    
    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    
    unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    hmacValue = [HMAC base64EncodedStringWithOptions:kNilOptions];
    
    return hmacValue;
}
-(void)scan{
    _session = [[AVCaptureSession alloc] init];
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    if (_input) {
        [_session addInput:_input];
    } else {
        NSLog(@"Error: %@", error);
    }
    
    _output = [[AVCaptureMetadataOutput alloc] init];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [_session addOutput:_output];
    
    _output.metadataObjectTypes = [_output availableMetadataObjectTypes];
    
    _prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _prevLayer.frame = self.view.bounds;
    _prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_prevLayer];
    
    [_session startRunning];

}
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult) result
{
    switch (result) {
        case MessageComposeResultCancelled:
            break;
            
        case MessageComposeResultFailed:
        {
            UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Failed to send SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [warningAlert show];
            break;
        }
            
        case MessageComposeResultSent:
            break;
            
        default:
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showSMS:(NSString*)number:(NSString*)msg {
    
    if(![MFMessageComposeViewController canSendText]) {
        UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Your device doesn't support SMS!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [warningAlert show];
        return;
    }
    
    NSArray *recipents = @[number];
    NSString *message = [NSString stringWithFormat:@"%@", msg];
    
    MFMessageComposeViewController *messageController = [[MFMessageComposeViewController alloc] init];
    messageController.messageComposeDelegate = self;
    [messageController setRecipients:recipents];
    [messageController setBody:message];
    
    // Present message view controller on screen
    [self presentViewController:messageController animated:YES completion:nil];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    
    if (!self.shouldSendReadBarcodeToDelegate)
    {
        //this means we have already captured at least one event, then we don't want   to call the delegate again
    }
    else
    {
        self.shouldSendReadBarcodeToDelegate = NO;
        //Your code for calling  the delegate should be here
        CGRect highlightViewRect = CGRectZero;
        AVMetadataMachineReadableCodeObject *barCodeObject;
        NSString *detectionString = nil;
        NSArray *barCodeTypes = @[AVMetadataObjectTypeUPCECode, AVMetadataObjectTypeCode39Code, AVMetadataObjectTypeCode39Mod43Code,
                                  AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode93Code, AVMetadataObjectTypeCode128Code,
                                  AVMetadataObjectTypePDF417Code, AVMetadataObjectTypeQRCode, AVMetadataObjectTypeAztecCode];
        for (AVMetadataObject *metadata in metadataObjects) {
            for (NSString *type in barCodeTypes) {
                if ([metadata.type isEqualToString:type])
                {
                    barCodeObject = (AVMetadataMachineReadableCodeObject *)[_prevLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metadata];
                    highlightViewRect = barCodeObject.bounds;
                    detectionString = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
                    break;
                }
            }
            if (detectionString != nil)
            {
                if ([detectionString rangeOfString:@"h2o"].location != NSNotFound) {
                    NSMutableArray *firstArray=(NSMutableArray*)[detectionString componentsSeparatedByString:@"h2o"];
                    NSMutableArray *secondArray=(NSMutableArray*)[[firstArray objectAtIndex:1] componentsSeparatedByString:@":"];
                   // [self showSMS:[secondArray objectAtIndex:0] :[secondArray objectAtIndex:1]];
                    qrcode=[[NSString alloc] init];
                    qrcode=[secondArray objectAtIndex:0];
                    //[self sendinfoToServer:[secondArray objectAtIndex:1]];
                    NSString *URLString = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.google.com"]];
                    NSString *result = [[NSString alloc] init];
                    result = ( URLString != NULL ) ? @"Yes" : @"No";
                    if([result isEqualToString:@"Yes"]){
                    [self ShowAlert];
                    }else{
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Inv Track"
                                                                        message:[NSString stringWithFormat:@"Internet connection availability No.!!!%@",qrcode]
                                                                       delegate:self
                                                              cancelButtonTitle:@"OK"
                                                              otherButtonTitles:nil];
                        [alert show];
                    }

                }else{
                    UIAlertView *alertview = [[UIAlertView alloc] initWithTitle:@"Inv Track"
                                                                    message:@"Invalid inv track code.."
                                                                   delegate:self
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alertview show];

                    
                }
               
        //        _label.text = detectionString;
                
                           }
            else
          //      _label.text = @"(none)";
            _highlightView.frame = highlightViewRect;
            
        }
       
        return;
    }

}
- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    // the user clicked one of the OK/Cancel buttons
    self.shouldSendReadBarcodeToDelegate = YES;
    [_session startRunning];

   }
-(void)callScan:(UIAlertView*)alert{
     [alert dismissWithClickedButtonIndex:0 animated:YES];
    self.shouldSendReadBarcodeToDelegate = YES;
    [_session startRunning];

}
-(void)sendinfoToServer:(NSString*)msg{
   
    [NSThread detachNewThreadSelector:@selector(threadStartAnimating:) toTarget:self withObject:nil];
    
    
    NSMutableString *httpBodyString;
    NSURL *url;
    NSMutableString *urlString;
    
    NSString *myString = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]];
    httpBodyString=[[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"qrcode=%@&gps=%f,%f&timestamp=%f&hmac=%@&comment=%@&phoneid=%@",qrcode,oldlat,oldlong,[[NSDate date] timeIntervalSince1970],[self hmacsha1:qrcode secret:myString],CommentStr,udid]];
    urlString=[[NSMutableString alloc] initWithString:@"http://h2otrack.com/trackerreceiver"];
    
    url=[[NSURL alloc] initWithString:urlString];
    
    NSMutableURLRequest *urlRequest=[NSMutableURLRequest requestWithURL:url];
    
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:[httpBodyString dataUsingEncoding:NSISOLatin1StringEncoding]];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        // your data or an error will be ready here
        if (error)
        {
            NSLog(@"Failed to submit request");
        }
        else
        {
            NSString *content = [[NSString alloc]  initWithBytes:[data bytes]
                                                          length:[data length] encoding: NSUTF8StringEncoding];
            NSLog(@"content %@",content);

            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Inv Track"
                                                            message:@"Scan Details uploaded successfully."
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
           

            [activityIndicator stopAnimating];

        }
    }];
    [activityIndicator stopAnimating];

}
-(UIView *)changeCmtAlert{
    UIView *demoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300,100)];
    [demoView setBackgroundColor:[UIColor whiteColor]];
    demoView.layer.cornerRadius=5;
    [demoView.layer setMasksToBounds:YES];
    [demoView.layer setBorderWidth:1.0];
    demoView.layer.borderColor=[[UIColor whiteColor]CGColor];
    
    CommentTxt=[[UITextView alloc] initWithFrame:CGRectMake(0,0, 250,58)];
    CommentTxt.text=@"Enter comment...";
    CommentTxt.delegate = self;
    [CommentTxt setFont:[UIFont boldSystemFontOfSize:18]];
    [demoView addSubview:CommentTxt];
    
    upDateBtn=[[UIButton alloc] initWithFrame:CGRectMake(0,60,149,50)];
    [upDateBtn setTitle:@"Submit" forState:UIControlStateNormal];
    [upDateBtn addTarget:self
                  action:@selector(enterComment)
        forControlEvents:UIControlEventTouchUpInside];
    [upDateBtn setBackgroundColor:[UIColor blackColor]];
    [demoView addSubview:upDateBtn];
    
    cancelBtn=[[UIButton alloc] initWithFrame:CGRectMake(151,60,150,50)];
    [cancelBtn setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelBtn addTarget:self
                  action:@selector(closeAlert:)
        forControlEvents:UIControlEventTouchUpInside];
    [cancelBtn setBackgroundColor:[UIColor blackColor]];
    [demoView addSubview:cancelBtn];
    return demoView;
    
}
-(void)enterComment{
    CommentStr=[[NSString alloc]init];
    CommentStr=CommentTxt.text;
    
   if ([CommentStr isEqualToString:@"Enter comment..."] || [CommentStr isEqualToString:@""]){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Inv Track"
                                                        message:@"Please enter comment to proceed !!!."
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }else{
        [self sendinfoToServer:CommentStr];
    }
    [alertView close];
}

-(void)closeAlert:(id)sender{
    
    [alertView close];
    self.shouldSendReadBarcodeToDelegate = YES;
    
    [_session startRunning];
}
-(void)WithoutCmt{
    [alertViewShow close];
    [self sendinfoToServer:CommentStr];
    
}

-(void)UpdateComment{
    [alertViewShow close];
    alertView = [[CustomIOS7AlertView alloc] init];
    
    // Add some custom content to the alert view
    [alertView setContainerView:[self changeCmtAlert]];
    
    // Modify the parameters
    
    [alertView setDelegate:self];
    
    // You may use a Block, rather than a delegate.
    [alertView setOnButtonTouchUpInside:^(CustomIOS7AlertView *alertView_, int buttonIndex) {
        NSLog(@"Block: Button at position %d is clicked on alertView %d.", buttonIndex, [alertView_ tag]);
        [alertView_ close];
    }];
    
    [alertView setUseMotionEffects:true];
    
    // And launch the dialog
    [alertView show];
}

-(void)ShowAlert{
    alertViewShow = [[CustomIOS7AlertView alloc] init];
    
    // Add some custom content to the alert view
    [alertViewShow setContainerView:[self showAlert]];
    
    // Modify the parameters
    
    [alertViewShow setDelegate:self];
    
    // You may use a Block, rather than a delegate.
    [alertViewShow setOnButtonTouchUpInside:^(CustomIOS7AlertView *alertView_, int buttonIndex) {
        NSLog(@"Block: Button at position %d is clicked on alertView %d.", buttonIndex, [alertView_ tag]);
        [alertView_ close];
    }];
    
    [alertViewShow setUseMotionEffects:true];
    
    // And launch the dialog
    [alertViewShow show];
}
-(void)closeAlertShow:(id)sender{
    [alertViewShow close];
}
-(UIView *)showAlert{
    
    
    UIView *demoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300,110)];
    [demoView setBackgroundColor:[UIColor whiteColor]];
    demoView.layer.cornerRadius=5;
    [demoView.layer setMasksToBounds:YES];
    [demoView.layer setBorderWidth:1.0];
    demoView.layer.borderColor=[[UIColor whiteColor]CGColor];
    
    CommentTxt=[[UITextView alloc] initWithFrame:CGRectMake(0,0,250,58)];
    CommentTxt.text=@"Do you want send comment with Bar code..?";
    [CommentTxt setFont:[UIFont boldSystemFontOfSize:18]];
    CommentTxt.editable=NO;
    CommentTxt.textColor = [UIColor blackColor];
    [demoView addSubview:CommentTxt];

    upDateBtn=[[UIButton alloc] initWithFrame:CGRectMake(0,60,149,50)];
    [upDateBtn setTitle:@"Yes" forState:UIControlStateNormal];
    [upDateBtn addTarget:self
                  action:@selector(UpdateComment)
        forControlEvents:UIControlEventTouchUpInside];
    [upDateBtn setBackgroundColor:[UIColor blackColor]];
    [demoView addSubview:upDateBtn];
    
    cancelBtn=[[UIButton alloc] initWithFrame:CGRectMake(151,60,150,50)];
    [cancelBtn setTitle:@"No" forState:UIControlStateNormal];
    [cancelBtn addTarget:self
                  action:@selector(WithoutCmt)
        forControlEvents:UIControlEventTouchUpInside];
    [cancelBtn setBackgroundColor:[UIColor blackColor]];
    [demoView addSubview:cancelBtn];
    return demoView;
    
}
-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@"Enter comment..."]) {
        textView.text = @"";
        textView.textColor = [UIColor blackColor]; //optional
    }
    
    [textView becomeFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@""]) {
        textView.text = @"Enter comment...";
        textView.textColor = [UIColor lightGrayColor]; //optional
    }
    [textView resignFirstResponder];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    if([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    
    return YES;
}

@end