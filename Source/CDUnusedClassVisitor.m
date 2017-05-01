// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004-2013 Steve Nygard.

#import "CDUnusedClassVisitor.h"

#import "CDOCClass.h"

@implementation CDUnusedClassVisitor
{
    NSMutableArray *_classes;
    NSMutableSet *_referencedClasses;
    NSMutableDictionary *_superClasses;
}

- (void)willBeginVisiting;
{
    [super willBeginVisiting];
    _classes = [[NSMutableArray alloc] init];
    _referencedClasses = [[NSMutableSet alloc] init];
    _superClasses = [[NSMutableDictionary alloc] init];
}

- (void)didEndVisiting;
{
    [super didEndVisiting];
    NSMutableSet *allReferencedClasses = [_referencedClasses mutableCopy];
    for (NSString *name in _referencedClasses) {
        NSString *superName = name;
        while (superName) {
            superName = [_superClasses valueForKey:superName];
            if (superName) {
                [allReferencedClasses addObject:superName];
            }
        }
    }
    NSUInteger classesDefined = [_classes count];
    [_classes removeObjectsInArray:allReferencedClasses.allObjects];
    [_classes sortUsingSelector:@selector(compare:)];
    NSString *separatedClasses = [_classes componentsJoinedByString:@", "];
    NSString *result = [[NSString alloc] initWithFormat:@"Classes Defined: %zd\nUnreferenced classes: %zd\n%@\n",
                        classesDefined, [_classes count], separatedClasses];
    NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:data];
}

- (void)didVisitClass:(CDOCClass *)aClass;
{
    [super didVisitClass:aClass];
    [_classes addObject:aClass.name];
    if (aClass.superClassName) {
        [_superClasses setObject:aClass.superClassName forKey:aClass.name];
    }
}

- (void)visitClassReference:(CDOCClass *)aClass;
{
    [super visitClassReference:aClass];
    [_referencedClasses addObject:aClass.name];
}

@end
