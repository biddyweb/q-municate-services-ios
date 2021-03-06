#import "CDMessage.h"
#import "CDAttachment.h"

@interface CDMessage ()

// Private interface goes here.

@end


@implementation CDMessage


- (QBChatHistoryMessage *)toQBChatHistoryMessage {
    
    QBChatHistoryMessage *chatHistoryMessage = [[QBChatHistoryMessage alloc] init];
    
    chatHistoryMessage.ID = self.id;
    chatHistoryMessage.text = self.text;
    chatHistoryMessage.recipientID = self.recipientID.intValue;
    chatHistoryMessage.senderID = self.senderID.intValue;
    chatHistoryMessage.datetime = self.datetime;
    chatHistoryMessage.dialogID = self.dialogID;
    chatHistoryMessage.customParameters = [self dictionaryWithBinaryData:self.customParameters].mutableCopy;
    chatHistoryMessage.read = self.isRead.boolValue;
    
    NSMutableArray *attachments = [NSMutableArray arrayWithCapacity:self.attachments.count];
    
    for (CDAttachment *cdAttachment in self.attachments) {
        
        QBChatAttachment *attachment = [cdAttachment toQBChatAttachment];
        [attachments addObject:attachment];
    }
    
    chatHistoryMessage.attachments = attachments;
    
    return chatHistoryMessage;
}

- (void)updateWithQBChatHistoryMessage:(QBChatHistoryMessage *)message {
    
    self.id = message.ID;
    self.text = message.text;
    self.datetime = message.datetime;
    self.recipientID = @(message.recipientID);
    self.senderID = @(message.senderID);
    self.dialogID = message.dialogID;
    self.customParameters = [self binaryDataWithDictionary:message.customParameters];
    self.isRead = @(message.isRead);
    //TODO
//    if (message.attachments.count > 0) {
//        
//        NSMutableSet *attachments = [NSMutableSet setWithCapacity:message.attachments.count];
//        
//        NSManagedObjectContext *context = [self managedObjectContext];
//        
//        for (QBChatAttachment *qbChatAttachment in message.attachments) {
//            
//            CDAttachment *attachment = [CDAttachment MR_createEntityInContext:context];
//            [attachment updateWithQBChatAttachment:qbChatAttachment];
//            [attachments addObject:attachment];
//        }
//        
//        [self setAttachments:attachments];
//    }
}

- (NSData *)binaryDataWithDictionary:(NSDictionary *)dictionary {
    
    NSData *binaryData = [NSKeyedArchiver archivedDataWithRootObject:dictionary];
    return binaryData;
}

- (NSDictionary *)dictionaryWithBinaryData:(NSData *)data {
    
    NSDictionary *dictionary = (NSDictionary*) [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return dictionary;
}

- (Class)objectClass {
    return [CDMessage class];
}

@end
