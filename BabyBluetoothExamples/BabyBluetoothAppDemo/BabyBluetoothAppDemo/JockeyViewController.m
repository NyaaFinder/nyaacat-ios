//
//  JockeyViewController.m
//  JockeyJS
//
//  Copyright (c) 2013, Tim Coulter
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "JockeyViewController.h"
#import "Jockey.h"
#import "ViewController.h"

//#import "UIColor-Expanded.h"

@interface JockeyViewController ()

@end

@implementation JockeyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self refresh];

    // Listen for a JS event.
    [Jockey on:@"log" perform:^(NSDictionary *payload) {
        NSLog(@"\"log\" received, payload = %@", payload);
    }];
    [Jockey on:@"setToken" perform:^(NSDictionary *payload) {
        NSLog(@"set token %@", [payload objectForKey:@"token"]);
        NSString *token = [payload objectForKey:@"token"];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setObject:token forKey:@"token"];
        [userDefaults synchronize];
        
    }];
    [Jockey on:@"selectPets" performAsync:^(UIWebView *webView, NSDictionary *payload, Complete complete) {
        UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        
        ViewController *bluelist = [story instantiateViewControllerWithIdentifier:@"bluelist"];
        bluelist.delegate = self;
        [self presentViewController:bluelist animated:YES completion:^{

        }];
//        complete(token);
        //        [self toggleFullscreen:complete withDuration:duration];
    }];

    
    [Jockey on:@"getToken" performAsync:^(UIWebView *webView, NSDictionary *payload, Complete complete) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *token = [userDefaults objectForKey:@"token"];
        complete(token);
//        [self toggleFullscreen:complete withDuration:duration];
    }];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return [Jockey webView:_webView withUrl:[request URL]];
}

- (IBAction)colorButtonPressed:(UIBarButtonItem *)sender {
    
    NSDictionary *payload = @{@"color": @"#334433"};
    
    [Jockey send:@"color-change" withPayload:payload toWebView:_webView];
}

- (IBAction)refreshButtonPressed:(UIBarButtonItem *)sender {
    [self refresh];
}

- (IBAction)showImageButtonPressed:(UIBarButtonItem *)sender {
    NSDictionary *payload = @{@"feed": @"http://www.google.com/doodles/doodles.xml"};
    
    [Jockey send:@"show-image" withPayload:payload toWebView:_webView perform:^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Image loaded"
                                                       message:@"callback in iOS from JS event"
                                                      delegate:self
                                              cancelButtonTitle:@"Score!"
                                              otherButtonTitles:nil];
        
        [alert show];
    }];
}

- (void)refresh {
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" ];
    
    NSString *path = [[NSBundle mainBundle] bundlePath];
    
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    baseURL = [NSURL URLWithString:@"http://ssh.jj.letme.repair:2398/index.html"];
    
    [_webView loadRequest:[NSURLRequest requestWithURL:baseURL]];
//    NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
//    [_webView loadHTMLString:htmlString baseURL:baseURL];
}

//- (void)toggleFullscreen:(Complete)complete withDuration:(NSTimeInterval)duration {
//    if (_fullscreenToggled) {
//        [self exitFullscreen:complete withDuration:duration];
//    } else {
//        [self enterFullscreen:complete withDuration:duration];
//    }
//}
//
//- (void)enterFullscreen:(Complete)complete withDuration:(NSTimeInterval)duration {
//    CGRect topFrame = _topToolbar.frame;
//    CGRect bottomFrame = _bottomToolbar.frame;
//    
//    [UIView animateWithDuration:duration animations:^{
//        _topToolbar.frame = CGRectMake(topFrame.origin.x, topFrame.origin.y-topFrame.size.height, topFrame.size.width, topFrame.size.height);
//        _bottomToolbar.frame = CGRectMake(bottomFrame.origin.x, bottomFrame.origin.y+bottomFrame.size.height, bottomFrame.size.width, bottomFrame.size.height);
//    
//        _webView.frame = CGRectMake(0,0,_webView.frame.size.width,_webView.frame.size.height+topFrame.size.height+bottomFrame.size.height);
//    } completion:^(BOOL finished) {
//        if (complete != nil) {
//            complete();
//        }
//    }];
//    
//    _fullscreenToggled = YES;
//}

- (void)exitFullscreen:(void(^)())complete withDuration:(NSTimeInterval)duration {
    CGRect topFrame = _topToolbar.frame;
    CGRect bottomFrame = _bottomToolbar.frame;
    
    [UIView animateWithDuration:duration animations:^{
        _topToolbar.frame = CGRectMake(topFrame.origin.x, topFrame.origin.y+topFrame.size.height, topFrame.size.width, topFrame.size.height);
        _bottomToolbar.frame = CGRectMake(bottomFrame.origin.x, bottomFrame.origin.y-bottomFrame.size.height, bottomFrame.size.width, bottomFrame.size.height);
    
        _webView.frame = CGRectMake(0,topFrame.size.height,_webView.frame.size.width,_webView.frame.size.height);
    } completion:^(BOOL finished) {
        // Clip off the extra bottom. It wasn't in the animation
        // because the bottom portion of the web view would blink.
        _webView.frame = CGRectMake(
                                    _webView.frame.origin.x,
                                    _webView.frame.origin.y,
                                    _webView.frame.size.width,
                                    _webView.frame.size.height-topFrame.size.height-bottomFrame.size.height
                                    );
        if (complete != nil) {
            complete();
        }
    }];
    
    _fullscreenToggled = NO;
}
-(BOOL)prefersStatusBarHidden{
    return YES;
}
-(void)pick:(NSString *)id name:(NSString*)name{
    [Jockey send:@"selectPetsDone" withPayload:@{@"id":id,@"name":name} toWebView:_webView];
}


@end
