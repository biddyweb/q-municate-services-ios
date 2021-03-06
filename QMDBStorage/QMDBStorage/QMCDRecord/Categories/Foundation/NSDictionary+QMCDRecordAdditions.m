//
//  NSDictionary+QMCDRecordAdditions.m
//  QMCDRecord
//
//  Created by Saul Mora on 9/14/13.
//  Copyright (c) 2013 QMCD Panda Software LLC. All rights reserved.
//

#import "NSDictionary+QMCDRecordAdditions.h"
#import "NSPersistentStoreCoordinator+QMCDRecord.h"

@implementation NSDictionary (QMCDRecordAdditions)

- (NSMutableDictionary *) QM_dictionaryByMergingDictionary:(NSDictionary *)dictionary;
{
    NSMutableDictionary *mutDict = [self mutableCopy];
    [mutDict addEntriesFromDictionary:dictionary];
    return mutDict;
}

+ (NSDictionary *) QM_defaultSqliteStoreOptions;
{
    return @{ @"journal_mode" : @"WAL" };
}

+ (NSDictionary *) QM_autoMigrationOptions;
{
    return @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
              NSInferMappingModelAutomaticallyOption : @YES };
}

+ (NSDictionary *) QM_manualMigrationOptions;
{
    return @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
              NSInferMappingModelAutomaticallyOption : @NO };
}

- (BOOL) QM_shouldDeletePersistentStoreOnModelMismatch;
{
    id value = [self valueForKey:QMCDRecordShouldDeletePersistentStoreOnModelMismatchKey];
    return [value boolValue];
}

@end
