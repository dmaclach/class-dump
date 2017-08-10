// -*- mode: ObjC -*-

//  This file is part of class-dump, a utility for examining the Objective-C segment of Mach-O files.
//  Copyright (C) 2017 Google Inc.

#import "CDUnreferencedSelectorVisitor.h"

#import "CDOCCategory.h"
#import "CDOCClass.h"
#import "CDOCMethod.h"

@implementation CDUnreferencedSelectorVisitor
{
    NSMutableDictionary *_declaredSelectors;
    NSMutableSet *_referencedSelectors;
    NSArray *_commonFalsePositiveREs;
    NSString *_classBeingParsed;
}

- (instancetype)init;
{
    if ((self = [super init])) {
        NSMutableArray *commonFalsePostiveREs = [[NSMutableArray alloc] init];
        NSArray *commonFalsePositives = @[
            @"[a-z]:will[A-Z]",
            @"[a-z]:did[A-Z]",
            @"[a-z]Did[A-Z]",
            @"[a-z]Will[A-Z]",
            @"^webView:[a-z]",
            @"^application:[a-z]",
            @"^collectionView:[a-z]",
            @"^tableView:[a-z]",
            @"^\\.cxx",
        ];
        for (NSString *entry in commonFalsePositives) {
            NSError *error;
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:entry
                                                                                options:0
                                                                                  error:&error];
            NSAssert(re, @"Unable to create RE: %@ (%@)", entry, error);
            [commonFalsePostiveREs addObject:re];
        }
        _commonFalsePositiveREs = [commonFalsePostiveREs copy];
    }
    return self;
}

- (void)willBeginVisiting;
{
    [super willBeginVisiting];
    _declaredSelectors = [[NSMutableDictionary alloc] init];
    _referencedSelectors = [[NSMutableSet alloc] init];
}

- (void)didEndVisiting;
{
    [super didEndVisiting];
    NSMutableSet *unReferencedSelectors = [NSMutableSet setWithArray:[_declaredSelectors allKeys]];
    [unReferencedSelectors minusSet:_referencedSelectors];
    NSMutableArray *unReferencedSignatures = [[NSMutableArray alloc] init];
    for (NSString *key in [unReferencedSelectors allObjects]) {
        [unReferencedSignatures addObjectsFromArray:_declaredSelectors[key]];
    }
    [unReferencedSignatures sortUsingSelector:@selector(compare:)];
    NSString *separatedSelectors = [unReferencedSignatures componentsJoinedByString:@"\n"];
    NSString *result = [[NSString alloc] initWithFormat:@"# Unreferenced selectors: %zd\n%@\n\n",
                        [unReferencedSignatures count], separatedSelectors];
    NSData *data = [result dataUsingEncoding:NSUTF8StringEncoding];
    [(NSFileHandle *)[NSFileHandle fileHandleWithStandardOutput] writeData:data];
}

- (void)willVisitClass:(CDOCClass *)aClass;
{
    _classBeingParsed = aClass.name;
}

- (void)didVisitClass:(CDOCClass *)aClass;
{
    _classBeingParsed = nil;
}

- (void)willVisitProtocol:(CDOCProtocol *)protocol;
{
    _classBeingParsed = protocol.name;
}

- (void)didVisitProtocol:(CDOCProtocol *)protocol;
{
    _classBeingParsed = nil;
}

- (void)willVisitCategory:(CDOCCategory *)category;
{
    _classBeingParsed = category.className;
}

- (void)didVisitCategory:(CDOCCategory *)category;
{
    _classBeingParsed = nil;
}

- (void)visitClassMethod:(CDOCMethod *)method;
{
    NSString *selector = method.name;
    NSString *signature = [NSString stringWithFormat:@"+ [%@ %@]", _classBeingParsed, selector];
    NSMutableArray *entries = _declaredSelectors[method.name];
    if (entries == nil) {
        _declaredSelectors[method.name] = [NSMutableArray arrayWithObject:signature];
    } else {
        [entries addObject:signature];
    }
}

- (void)visitInstanceMethod:(CDOCMethod *)method
              propertyState:(CDVisitorPropertyState *)propertyState;
{
    NSString *selector = method.name;
    NSRange fullString = NSMakeRange(0, selector.length);
    for (NSRegularExpression *exp in _commonFalsePositiveREs) {
        if ([exp numberOfMatchesInString:selector options:0 range:fullString]) {
            return;
        }
    }
    NSString *signature = [NSString stringWithFormat:@"- [%@ %@]", _classBeingParsed, selector];
    NSMutableArray *entries = _declaredSelectors[method.name];
    if (entries == nil) {
        _declaredSelectors[method.name] = [NSMutableArray arrayWithObject:signature];
    } else {
        [entries addObject:signature];
    }
}

- (void)visitSelectorReference:(NSString *)aSelector {
    [_referencedSelectors addObject:aSelector];
}
@end
