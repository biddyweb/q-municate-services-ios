//
//  QMBaseAuthService.m
//  Q-municate
//
//  Created by Andrey Ivanov on 29.10.14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMAuthService.h"

@interface QMAuthService()

@property (strong, nonatomic) QBMulticastDelegate <QMAuthServiceDelegate> *multicastDelegate;

@property (assign, nonatomic) BOOL isAuthorized;

@end

@implementation QMAuthService

- (void)dealloc {
    
    NSLog(@"%@ - %@",  NSStringFromSelector(_cmd), self);
}

#pragma  mark Add / Remove multicast delegate

- (void)addDelegate:(id <QMAuthServiceDelegate>)delegate {
    
    [self.multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id <QMAuthServiceDelegate>)delegate {
    
    [self.multicastDelegate addDelegate:delegate];
}

#pragma mark - Will Start

- (void)willStart {
    [super willStart];
    
    self.multicastDelegate = (id<QMAuthServiceDelegate>)[[QBMulticastDelegate alloc] init];
}

- (QBRequest *)logOut:(void(^)(QBResponse *response))completion {
    
    __weak __typeof(self)weakSelf = self;
    
    QBRequest *request =
    [QBRequest logOutWithSuccessBlock:^(QBResponse *response) {
        //Notify subscribes abot logout
        if ([weakSelf.multicastDelegate respondsToSelector:@selector(authServiceDidLogOut)]) {
            [weakSelf.multicastDelegate authServiceDidLogOut];
        }
        
        weakSelf.isAuthorized = NO;
        
        if (completion)
            completion(response);
        
    } errorBlock:^(QBResponse *response) {
        
        [weakSelf showMessageForQBResponce:response];
        
        if (completion)
            completion(response);
    }];
    
    return request;
}

- (QBRequest *)signUpAndLoginWithUser:(QBUUser *)user completion:(void(^)(QBResponse *response, QBUUser *userProfile))completion {
    
    __weak __typeof(self)weakSelf = self;
    
    QBRequest *request =
    //1. Signup
    [QBRequest signUp:user successBlock:^(QBResponse *response, QBUUser *newUser) {
        //2. Login
        [weakSelf logInWithUser:user completion:completion];
        
    } errorBlock:^(QBResponse *response) {
        
        [weakSelf showMessageForQBResponce:response];
        
        if (completion)
            completion(response, nil);
    }];
    
    return request;
}

#pragma mark - Private methods

- (QBRequest *)logInWithUser:(QBUUser *)user completion:(void(^)(QBResponse *response, QBUUser *userProfile))completion {
    
    __weak __typeof(self)weakSelf = self;
    //Common error block
    void (^errorBlock)(id) = ^(QBResponse *response){
        
        [weakSelf showMessageForQBResponce:response];
        completion(response, nil);
    };
    
    void (^successBlock)(id, id) = ^(QBResponse *response, QBUUser *userProfile){
        
        weakSelf.isAuthorized = YES;
        completion(response, userProfile);
    };
    
    QBRequest *request = nil;
    
    if (user.email) {
        
        request =
        [QBRequest logInWithUserEmail:user.email password:user.password successBlock:successBlock errorBlock:errorBlock];
    }
    else if (user.login) {
        
        request =
        [QBRequest logInWithUserLogin:user.login password:user.password successBlock:successBlock errorBlock:errorBlock];
    }
    
    return request;
}

#pragma mark - Social auth

- (QBRequest *)logInWithFacebookSessionToken:(NSString *)sessionToken
                                  completion:(void(^)(QBResponse *response, QBUUser *userProfile))completion {
    
    __weak __typeof(self)weakSelf = self;
    
    QBRequest *request =
    [QBRequest logInWithSocialProvider:@"facebook" accessToken:sessionToken accessTokenSecret:nil
                          successBlock:^(QBResponse *response, QBUUser *tUser)
     {
         weakSelf.isAuthorized = YES;
         //set password
         tUser.password = [QBBaseModule sharedModule].token;
         completion(response, tUser);
         
     } errorBlock:^(QBResponse *response) {
         
         [weakSelf showMessageForQBResponce:response];
         
         if (completion)
             completion(response, nil);
     }];
    
    return request;
}

@end