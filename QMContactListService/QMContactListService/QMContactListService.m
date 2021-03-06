//
//  QMContactsService.m
//  Q-municate
//
//  Created by Andrey Ivanov on 14/02/2014.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import "QMContactListService.h"

@interface QMContactListService()

<QBChatDelegate>

@property (strong, nonatomic) QBMulticastDelegate <QMContactListServiceDelegate> *multicastDelegate;
@property (weak, nonatomic) id<QMContactListServiceCacheDelegate> cahceDelegate;
@property (strong, nonatomic) QMContactListMemoryStorage *contactListMemoryStorage;
@property (strong, nonatomic) QMUsersMemoryStorage *usersMemoryStorage;
@property (strong, nonatomic) NSMutableSet *retrivedIds;

@end

@implementation QMContactListService

- (void)dealloc {
    
    NSLog(@"%@ - %@",  NSStringFromSelector(_cmd), self);
    [[QBChat instance] removeDelegate:self];
    self.contactListMemoryStorage = nil;
}

- (instancetype)initWithUserProfileDataSource:(id<QMUserProfileProtocol>)userProfileDataSource
                                cacheDelegate:(id<QMContactListServiceCacheDelegate>)cacheDelegate {
    
    self = [super initWithUserProfileDataSource:userProfileDataSource];
    if (self) {
        
        self.cahceDelegate = cacheDelegate;
        self.retrivedIds = [NSMutableSet set];
        [self loadCachedData];
        
    }
    return self;
}

- (void)loadCachedData {
    
    __weak __typeof(self)weakSelf = self;
    
    dispatch_queue_t queue = dispatch_queue_create("com.qm.loadCacheQueue", DISPATCH_QUEUE_SERIAL);
    //Step 1. Load contact list (Roster)
    dispatch_async(queue, ^{
        
        if ([self.cahceDelegate respondsToSelector:@selector(cachedContactListItems:)]) {
            
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            
            [self.cahceDelegate cachedContactListItems:^(NSArray *collection) {
                
                [weakSelf.contactListMemoryStorage updateWithContactListItems:collection];
                dispatch_semaphore_signal(sem);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
    });
    //Step 2. Load users for conatc list
    dispatch_async(queue, ^{
        
        if ([self.cahceDelegate respondsToSelector:@selector(cachedUsers:)]) {
            
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            
            [self.cahceDelegate cachedUsers:^(NSArray *collection) {
                
                [weakSelf.usersMemoryStorage addUsers:collection];
                dispatch_semaphore_signal(sem);
            }];
            
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
    });
    //Step 3. Notify about load cache
    dispatch_async(queue, ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.multicastDelegate respondsToSelector:@selector(contactListServiceDidLoadCache)]) {
                [self.multicastDelegate contactListServiceDidLoadCache];
            }
        });
    });
}

- (void)willStart {
    [super willStart];
    
    self.multicastDelegate = (id<QMContactListServiceDelegate>)[[QBMulticastDelegate alloc] init];
    self.contactListMemoryStorage = [[QMContactListMemoryStorage alloc] init];
    self.usersMemoryStorage = [[QMUsersMemoryStorage alloc] init];
    [[QBChat instance] addDelegate:self];
}

#pragma mark - Add Remove multicaste delegate

- (void)addDelegate:(id <QMContactListServiceDelegate>)delegate {
    
    [self.multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id <QMContactListServiceDelegate>)delegate {
    
    [self.multicastDelegate removeDelegate:delegate];
}

#pragma mark - QBChatDelegate

- (void)chatContactListDidChange:(QBContactList *)contactList {
    
    [self.contactListMemoryStorage updateWithContactList:contactList];
    
    __weak __typeof(self)weakSelf = self;
    
    [self retrieveUsersWithIDs:[self.contactListMemoryStorage userIDsFromContactList]
                    completion:^(QBResponse *responce, QBGeneralResponsePage *page, NSArray *users)
     {
         if (responce.success) {
             
             if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:contactListDidChange:)]) {
                 
                 [weakSelf.multicastDelegate contactListService:self
                                           contactListDidChange:contactList];
             }
         }
     }];
}

- (void)chatDidReceiveContactAddRequestFromUser:(NSUInteger)userID {
    
    [self.contactListMemoryStorage addContactRequestFromUserID:userID];
    
    QBUUser *user = [self.usersMemoryStorage userWithID:userID];
    
    if (user) {
        
        if ([self.multicastDelegate respondsToSelector:@selector(contactListService:addRequestFromUser:)]) {
            
            [self.multicastDelegate contactListService:self addRequestFromUser:user];
        }
    }
    else {
        
        __weak __typeof(self)weakSelf = self;
        
        [self retrieveUsersWithIDs:@[@(userID)] completion:^(QBResponse *responce, QBGeneralResponsePage *page, NSArray *users){
            
            if (users.count == 0) {
                return;
            }
            
            QBUUser *newUser = users.firstObject;
            
            [weakSelf.usersMemoryStorage addUser:newUser];
            
            if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:addRequestFromUser:)]) {
                [weakSelf.multicastDelegate contactListService:weakSelf addRequestFromUser:newUser];
            }
            
            if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:didAddUser:)]) {
                [weakSelf.multicastDelegate contactListService:weakSelf didAddUser:newUser];
            }
        }];
    }
}

#pragma mark - Retrive users

- (NSMutableSet *)checkExistIds:(NSArray *)ids {
    
    NSMutableSet *toFetch = [NSMutableSet setWithArray:ids];
    
    for (NSNumber *userID in ids) {
        
        QBUUser *savedUser = [self.usersMemoryStorage userWithID:userID.unsignedIntegerValue];
        BOOL inProgress = [self.retrivedIds containsObject:userID];
        
        if (savedUser || inProgress) {
            [toFetch removeObject:userID];
        }
    }
    
    return toFetch;
}

- (void)retrieveUsersWithIDs:(NSArray *)ids
                  completion:(void(^)(QBResponse *responce,
                                      QBGeneralResponsePage *page,
                                      NSArray * users))completion {
    
    NSSet *toRetrive = [self checkExistIds:ids].copy;
    
    NSLog(@"RetrieveUsers %@", toRetrive);
    
    if (toRetrive.count == 0) {
        completion(nil, nil, nil);
    }
    else {
        
        QBGeneralResponsePage *pageResponce =
        [QBGeneralResponsePage responsePageWithCurrentPage:1
                                                   perPage:toRetrive.count < 100 ? toRetrive.count : 100];
        __weak __typeof(self)weakSelf = self;
        
        [self.retrivedIds unionSet:toRetrive];
        
        [QBRequest usersWithIDs:toRetrive.allObjects
                           page:pageResponce
                   successBlock:^(QBResponse *responce, QBGeneralResponsePage *page, NSArray * users)
         {
             for (QBUUser *user in users) {
                 [weakSelf.retrivedIds removeObject:@(user.ID)];
             }
             
             [weakSelf.usersMemoryStorage addUsers:users];
             
             if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:didAddUsers:)]) {
                 
                 [weakSelf.multicastDelegate contactListService:weakSelf
                                                    didAddUsers:users];
             }
             
             if (completion) {
                 completion(responce, page, users);
             }
             
         } errorBlock:^(QBResponse *responce) {
             
             completion(responce, nil, nil);
         }];
    }
}

- (void)retriveUsersForChatDialog:(QBChatDialog *)chatDialog
                       completion:(void(^)(QBResponse *responce, QBGeneralResponsePage *page, NSArray * users))completion {
    
    __weak __typeof(self)weakSelf = self;
    
    [self retrieveUsersWithIDs:chatDialog.occupantIDs
                    completion:^(QBResponse *responce,
                                 QBGeneralResponsePage *page,
                                 NSArray *users)
     {
         if (users.count > 0 ) {
             
             if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:didFinishRetriveUsersForChatDialog:)]) {
                 
                 [weakSelf.multicastDelegate contactListService:weakSelf
                             didFinishRetriveUsersForChatDialog:chatDialog];
             }
             
         }
         
         if (completion) {
             completion(responce, page, users);
         }
     }];
}

#pragma mark - ContactList Request

- (void)addUserToContactListRequest:(QBUUser *)user
                         completion:(void(^)(BOOL success))completion {
    
    
    __weak __typeof(self)weakSelf = self;
    [[QBChat instance] addUserToContactListRequest:user.ID
                                         sentBlock:^(NSError *error)
     {
         if (!error) {
             
             [weakSelf.usersMemoryStorage addUser:user];
             
             if ([weakSelf.multicastDelegate respondsToSelector:@selector(contactListService:didAddUser:)]) {
                 
                 [weakSelf.multicastDelegate contactListService:weakSelf
                                                     didAddUser:user];
             }
             
             if (completion) {
                 completion(YES);
             }
             
         } else {
             
             if (completion) {
                 completion(YES);
             }
         }
     }];
}

- (void)removeUserFromContactListWithUserID:(NSUInteger)userID
                                 completion:(void(^)(BOOL success))completion {
    
    [[QBChat instance] removeUserFromContactList:userID
                                       sentBlock:^(NSError *error)
     {
         if (!error) {
             
             if (completion) {
                 completion(YES);
             }
             
         } else {
             
             if (completion) {
                 completion(YES);
             }
         }
     }];
}

- (void)confirmAddContactRequest:(NSUInteger)userID
                      completion:(void(^)(BOOL success))completion {
    
    __weak __typeof(self)weakSelf = self;
    [[QBChat instance] confirmAddContactRequest:userID
                                      sentBlock:^(NSError *error)
     {
         if (!error) {
             
             [weakSelf.contactListMemoryStorage confirmOrRejectContactRequestForUserID:userID];
             
             if (completion) {
                 completion(YES);
             }
             
         } else {
             
             if (completion) {
                 completion(YES);
             }
         }
     }];
}

- (void)rejectAddContactRequest:(NSUInteger)userID
                     completion:(void(^)(BOOL success))completion {
    
    [[QBChat instance]  rejectAddContactRequest:userID
                                      sentBlock:^(NSError *error)
     {
         if (!error) {
             
             [self.contactListMemoryStorage confirmOrRejectContactRequestForUserID:userID];
             
             if (completion) {
                 completion(YES);
             }
             
         } else {
             
             if (completion) {
                 completion(YES);
             }
         }
     }];
}

- (NSArray *)usersWithoutMeWithIDs:(NSArray *)IDs {
    
    QBUUser *user = [self.userProfileDataSource currentUser];
    NSParameterAssert(user);
    
    NSMutableArray *withoutMeIDs = IDs.mutableCopy;
    [withoutMeIDs removeObject:@(user.ID)];
    
    return [self.usersMemoryStorage usersWithIDs:withoutMeIDs];
}

- (NSArray *)usersFromContactListSortedByFullName {
    
    NSSortDescriptor *sorter =
    [[NSSortDescriptor alloc] initWithKey:@"fullName" ascending:YES
                                 selector:@selector(localizedCaseInsensitiveCompare:)];
    
    NSArray *sortedUsers = [self.usersFromContactList sortedArrayUsingDescriptors:@[sorter]];
    
    return sortedUsers;
}

#pragma mark - Memory storage

- (NSArray *)usersFromContactList {
    
    NSArray *friendsIDS = [self.contactListMemoryStorage userIDsFromContactList];
    NSArray *friends = [self.usersMemoryStorage usersWithIDs:friendsIDS];
    
    return friends;
}

#pragma QMMemoryStorageProtocol

- (void)free {
    
    [self.contactListMemoryStorage free];
    [self.usersMemoryStorage free];
}

@end
