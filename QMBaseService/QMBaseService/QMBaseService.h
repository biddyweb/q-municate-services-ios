//
//  QMBaseService.h
//  Q-municate
//
//  Created by Andrey Ivanov on 04.08.14.
//  Copyright (c) 2014 Quickblox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QMMemoryStorageProtocol.h"
#import "QMUserProfileProtocol.h"

@interface QMBaseService : NSObject <QMMemoryStorageProtocol>

@property (weak, nonatomic, readonly) id <QMUserProfileProtocol> userProfileDataSource;

- (id)init __attribute__((unavailable("init is not a supported initializer for this class.")));

- (instancetype)initWithUserProfileDataSource:(id<QMUserProfileProtocol>)userProfileDataSource;

/**
 *  Called when the servise is will begin start
 */
- (void)willStart;

/**
 *  Handle QBResponce
 *
 *  @param responce QBResponse instanse
 */
- (void)showMessageForQBResponce:(QBResponse *)responce;

@end
