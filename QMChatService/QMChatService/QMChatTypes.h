//
//  QMChatTypes.h
//  QMChatService
//
//  Created by Andrey Ivanov on 29.04.15.
//
//

typedef NS_ENUM(NSUInteger, QMMessageType) {

    /** Default message type*/
    QMMessageTypeDefault,
    QMMessageTypeNotificationAboutCreateGroupDialog,
    QMMessageTypeNotificationAboutUpdateGroupDialog,
    
    QMMessageTypeNotificationAboutSendContactRequest,
    QMMessageTypeNotificationAboutConfirmContactRequest,
    QMMessageTypeNotificationAboutRejectContactRequest,
    QMMessageTypeNotificationAboutDeleteContactRequest
};

