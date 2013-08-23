//
//  MMViewControllerTests.m
//  UnitTestsPartTwo
//
//  Created by Sean McMains on 8/23/13.
//  Copyright (c) 2013 Mutual Mobile. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>
#import <objc/runtime.h>

static BOOL calledSuper = NO;

@interface UIViewController (ViewLifeCycleTesting)

- (void)superOverride;
- (void)superOverride:(BOOL)animated;

@end

@implementation UIViewController (ViewLifeCycleTesting)

- (void)superOverride{
    calledSuper = YES;
    [self superOverride];
}

- (void)superOverride:(BOOL)animated{
    calledSuper = YES;
    [self superOverride:animated];
}

@end

@interface MMViewControllerTests : GHTestCase

@end

@implementation MMViewControllerTests

-(instancetype)init {
    self = [super init];
    if(self){
        NSArray *subclassesToTest = ClassGetSubclasses([UIViewController class]);
        [self createTestCasesForClasses:subclassesToTest];
    }
    return self;
}

- (BOOL)shouldRunOnMainThread{
    return YES;
}

- (void)setUp{
    [super setUp];
    
    calledSuper = NO;
}

- (void)createTestCasesForClasses:(NSArray *)subclasses{
    for (Class klass in subclasses) {
        
        [self createTestsForClass:klass
                         selector:@selector(viewDidLoad)
        testSelectorIncludesParam:NO
                    withTestBlock:nil];
        [self createTestsForClass:klass
                         selector:@selector(viewWillAppear:)
        testSelectorIncludesParam:YES
                    withTestBlock:^(id testInstance) {
                        [testInstance viewWillAppear:NO];
                    }];
        [self createTestsForClass:klass
                         selector:@selector(viewDidAppear:)
        testSelectorIncludesParam:YES
                    withTestBlock:^(id testInstance) {
                        [testInstance viewDidAppear:NO];
                    }];
        [self createTestsForClass:klass
                         selector:@selector(viewWillDisappear:)
        testSelectorIncludesParam:YES
                    withTestBlock:^(id testInstance) {
                        [testInstance viewWillDisappear:NO];
                    }];
        [self createTestsForClass:klass
                         selector:@selector(viewDidDisappear:)
        testSelectorIncludesParam:YES
                    withTestBlock:^(id testInstance) {
                        [testInstance viewDidDisappear:NO];
                    }];
    }
}

- (void)createTestsForClass:(Class)klass
                   selector:(SEL)selectorToTest
  testSelectorIncludesParam:(BOOL)includesParam
              withTestBlock:(void(^)(id testInstance))lifecycleTestBlock{
    
    unsigned int numMethods;
    Method *methods = class_copyMethodList(klass, &numMethods);
    BOOL implementsSpecifiedSelector = NO;
    
    for (int i = 0; i < numMethods; i++) {
        NSString *foundMethodName = NSStringFromSelector(method_getName(methods[i]));
        if ([foundMethodName isEqualToString:NSStringFromSelector(selectorToTest)]) {
            implementsSpecifiedSelector = YES;
            break;
        }
    }
    
    if (implementsSpecifiedSelector){
        NSString *newSelectorString = [NSString stringWithFormat:@"test%@CallsSuper%@", NSStringFromClass(klass), NSStringFromSelector(selectorToTest)];
        SEL newSelector = NSSelectorFromString(newSelectorString);
        
        void(^testBlock)(void) = ^(void){
            id classInstance = [[klass alloc] init];
            
            Method origMethod = class_getInstanceMethod([klass superclass], selectorToTest);
            
            SEL selectorToSwizzleIn = @selector(superOverride);
            if (includesParam) {
                selectorToSwizzleIn = @selector(superOverride:);
            }
            Method newMethod = class_getInstanceMethod([klass superclass], selectorToSwizzleIn);
            
            method_exchangeImplementations(origMethod, newMethod);
            
            __unused UIView *view;
            @try {
                view = [classInstance view];
            }
            @catch (NSException *exception) {}
            
            if (lifecycleTestBlock != nil) {
                lifecycleTestBlock(classInstance);
            }
            
            method_exchangeImplementations(newMethod, origMethod);
            
            // We have to use +initialize to get this all set up before
            // XCTest does its probe of the test classes. Unfortunately, the
            // standard XCT assertions don't work correctly from a class method,
            // so we have to use NSAssert instead.
            GHAssertTrue(calledSuper,
                     @"%@ did not call super", NSStringFromSelector(selectorToTest));
        };
        
        IMP newMethodIMP = imp_implementationWithBlock(testBlock);
        
        class_addMethod(self.class, newSelector, newMethodIMP, "v@:");
    }
}




/**
 http://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html
 */
NSArray *ClassGetSubclasses(Class parentClass)
{
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;
    
    classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++)
    {
        Class superClass = classes[i];
        do
        {
            superClass = class_getSuperclass(superClass);
        } while(superClass && superClass != parentClass);
        
        if (superClass == nil)
        {
            continue;
        }
        
        NSString *className = NSStringFromClass(classes[i]);
        
        NSLog(@"FOO: %@", [className substringToIndex:2]);
        BOOL classShouldBeTested = [[className substringToIndex:2] isEqualToString:@"MM"];
        if ( classShouldBeTested ) {
            [result addObject:classes[i]];
        }
    }
    
    free(classes);
    
    return result;
}




@end

