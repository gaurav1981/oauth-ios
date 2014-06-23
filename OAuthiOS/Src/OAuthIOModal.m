/*
 * (C) Copyright 2013 Webshell SAS.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "OAuthIOModal.h"

@implementation OAuthIOModal

NSString *_host;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return (self);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (_browser == nil) {
        _browser = [[UIWebView alloc] init];
    }

    [_browser setFrame:CGRectMake(0, _navigationBarHeight, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height - _navigationBarHeight - 1)];
    _browser.autoresizesSubviews = YES;
    _browser.autoresizingMask=(UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    [_browser setDelegate:self];
    [[self view] addSubview:_browser];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getTokens:) name:@"OAuthIOGetTokens" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithKey:(NSString *)key delegate:(id)delegate
{
    return [self initWithKey:key delegate:delegate andOptions:nil];
}

- (id)initWithKey:(NSString *)key delegate:(id)delegate andOptions:(NSDictionary *) options
{
    self = [super init];
    
    if (!self || ![self initCustomCallbackURL])
        return (nil);
    
    [self setDelegate:delegate];
    
    if (options != nil) {
        if ([options objectForKey:@"webview"] != nil) {
            _browser = [options objectForKey:@"webview"];
        }
    }
    
    _key = key;
    _oauth = [[OAuthIO alloc] initWithKey:_key];
    _rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
        _navigationBarHeight = NAVIGATION_BAR_HEIGHT_IOS7_OR_LATER;
    else
        _navigationBarHeight = NAVIGATION_BAR_HEIGHT_IOS6_OR_EARLIER;
    
    [self initNavigationBar];
    
    return (self);
}

- (NSMutableDictionary *)mutableDeepCopy:(NSDictionary *)dictionary
{
    NSMutableDictionary * ret = [[NSMutableDictionary alloc]
                                 initWithCapacity:[dictionary count]];
    
    NSMutableArray * array;
    
    for (id key in [dictionary allKeys])
    {
        array = [(NSArray *)[dictionary objectForKey:key] mutableCopy];
        [ret setValue:array forKey:key];
    }
    
    return ret;
}

- (void)getTokens:(NSString *)url
{
    url = [OAuthIORequest decodeURL:url];

    NSUInteger start_pos = [url rangeOfString:@"="].location + 1;
    NSString *json = [url substringWithRange:NSMakeRange(start_pos, [url length] - start_pos)];
    NSDictionary *json_dic = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableLeaves error:nil];
    NSMutableDictionary *json_dic_m = [self mutableDeepCopy:json_dic];
    if ([[json_dic_m objectForKey:@"data"] objectForKey:@"expires_in"])
    {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *expires_in = [[json_dic_m objectForKey:@"data"] objectForKey:@"expires_in"];
        NSTimeInterval timeInterval = [expires_in doubleValue];
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:timeInterval];
        NSString *expires = [NSString stringWithFormat:@"%f", [date timeIntervalSince1970]];
        NSMutableDictionary *json_dic_m_data = [json_dic_m objectForKey:@"data"];
        [json_dic_m_data setObject:[NSString stringWithFormat:@"%@", expires] forKey:@"expires"];
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json_dic_m
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
        json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    
    
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];

    if (_options != nil && [[_options objectForKey:@"cache"] isEqualToString:@"true"])
    {

        NSString *provider = [data objectForKey:@"provider"];
    
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *file_url = [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"oauthio-%@.json", provider]];
        NSData *data_to_file = [json dataUsingEncoding:NSUTF8StringEncoding];
        [data_to_file writeToFile:file_url atomically:YES];
    }
    
    @try {
        OAuthIORequest *request = [self buildRequestObject:json];
        if ([self.delegate respondsToSelector:@selector(didReceiveOAuthIOResponse:)])
            [self.delegate didReceiveOAuthIOResponse:request];
    }
    @catch (NSException *e) {
        NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
        [errorDetail setValue:[NSString stringWithFormat:@"%@", e.description] forKey:NSLocalizedDescriptionKey];
        NSError *error = [[NSError alloc] initWithDomain:@"OAuthIO" code:100 userInfo:errorDetail];
        if ([self.delegate respondsToSelector:@selector(didFailWithOAuthIOError:)])
            [self.delegate didFailWithOAuthIOError:error];
    }
    
    
    
    
}

- (OAuthIORequest *)buildRequestObject:(NSString *)json
{
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    
    if (jsonData)
    {
        NSError *error = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        
        if (error)
        {
            [NSException raise:@"JSON parser error" format:@"%@", [error description]];
            return nil;
        }
        
        _oauthio_data = [[OAuthIOData alloc] initWithDictionary:jsonDict];
        OAuthIORequest *request = [[OAuthIORequest alloc] initWithOAuthIOData:_oauthio_data];
        
        return request;
    }
    else
    {
        [NSException raise:@"Invalid data" format:@"The provided string is invalid"];
        return nil;
    }
}


# pragma mark - Toolbar methods

- (void)initNavigationBar
{
    _navigationBar = [[UINavigationBar alloc] init];
    [_navigationBar setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth];
    
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@""];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:nil action:@selector(cancelOperation)];
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:nil action:@selector(refreshOperation)];
    
    [navItem setRightBarButtonItem:cancelButton];
    [navItem setLeftBarButtonItem:refreshButton];
    
    [_navigationBar pushNavigationItem:navItem animated:NO];
    
    [self drawNavigationBar];
}

- (void)drawNavigationBar
{
    CGFloat width = CGRectGetWidth(self.view.bounds);
    [_navigationBar setFrame:CGRectMake(0, 0, width, _navigationBarHeight)];
    [self.view addSubview:_navigationBar];
}

- (void)refreshOperation
{
    [_browser reload];
}

- (void)cancelOperation
{
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:@"Operation canceled" forKey:NSLocalizedDescriptionKey];
    NSError *error = [[NSError alloc] initWithDomain:@"OAuthIO" code:100 userInfo:errorDetail];
    
    if ([self.delegate respondsToSelector:@selector(didFailWithOAuthIOError:)])
        [self.delegate didFailWithOAuthIOError:error];    

    [_browser loadHTMLString:nil baseURL:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)initCustomCallbackURL
{

    _scheme = @"oauthio";
    _host = @"localhost";
    _callback_url = [[NSString alloc] initWithFormat:@"%@://%@", _scheme, _host];
    
    return (YES);

}

- (void)showWithProvider:(NSString *)provider {
    [self showWithProvider:provider options:nil];
}

- (void)showWithProvider:(NSString *)provider options:(NSDictionary*)options
{
    _options = options;
    if (_options != nil && [[_options objectForKey:@"cache"] isEqualToString:@"true"])
    {
        // Try to retrieve objects from cache
        // Needs to be improved to handle expires_in
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *file_url = [cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"oauthio-%@.json", provider]];
        if([fileManager fileExistsAtPath:file_url])
        {
            NSString *json = [NSString stringWithContentsOfFile:file_url encoding:NSUTF8StringEncoding error:NULL];
            NSDictionary *json_d = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options: NSJSONReadingMutableContainers error:nil];
            NSNumber *expires = [[json_d objectForKey:@"data"] objectForKey:@"expires"];
            NSTimeInterval interval = [expires doubleValue];
            NSDate *expiring_date = [[NSDate alloc] initWithTimeIntervalSince1970:interval];
            NSDate *now = [[NSDate alloc] init];
            if ([now compare:expiring_date] == NSOrderedAscending)
            {
                @try {
                    OAuthIORequest *request = [self buildRequestObject:json];
                    if ([self.delegate respondsToSelector:@selector(didReceiveOAuthIOResponse:)])
                        [self.delegate didReceiveOAuthIOResponse:request];
                }
                @catch (NSException *e) {
                    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
                    [errorDetail setValue:@"Could not read cache" forKey:NSLocalizedDescriptionKey];
                    NSError *error = [[NSError alloc] initWithDomain:@"OAuthIO" code:100 userInfo:errorDetail];
                    
                    if ([self.delegate respondsToSelector:@selector(didFailWithOAuthIOError:)])
                        [self.delegate didFailWithOAuthIOError:error];
                }
                
                return;

            }
        }
    }
    
    NSURLRequest *url = [_oauth getOAuthRequest:provider andUrl:_callback_url andOptions:options];
    [_rootViewController presentViewController:self animated:YES completion:^{
        [_browser loadRequest:url];
    }];
}

#pragma mark - UIWebView delegate method

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = request.URL;
    
    if (![url.scheme isEqual:@"http"] && ![url.scheme isEqual:@"https"] && ![url.scheme isEqual:@"file"])
    {
        if ([url.scheme isEqual:@"oauthio"] && [url.host isEqual:@"localhost"])
        {
            [self dismissViewControllerAnimated:YES completion:nil];
            [self getTokens:[url absoluteString]];
            return (NO);
        }
    }
    
    return (YES);
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([error.domain isEqualToString:@"NSURLErrorDomain"] && error.code == -999)
        return;
    
    if ([self.delegate respondsToSelector:@selector(didFailWithOAuthIOError:)])
        [self.delegate didFailWithOAuthIOError:error];
}

@end
