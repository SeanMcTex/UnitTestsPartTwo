# Unit Tests That Write Themselves: Part Two

In the first article in this series, we set up an abstract parent class for our view controller tests and used Objective C's runtime library to create dynamically named tests for all of its concrete subclasses. This technique can save us a lot of time, but we still have to remember to create a new test case whenever we create a new view controller class. Can we make tests even more automatic? By gazing deep into the arcane mysteries of the runtime system, we will answer this question and, if we're lucky, discover a little bit about love along the way[^1]. (*Editor's Note:* We will not actually discover anything about love.)

## The Case for Automated Test Creation

In iOS, view controllers get certain lifecycle events from the system: `viewDidLoad`, `viewWillAppear`, `viewDidAppear`, `viewWillDisappear` and `viewDidDisappear`. When we write a view controller, we almost always implement these methods to customize that view controller's behavior. 

If you're anything like me, however, you often forget to call the superclass' implementation of those methods, which is naughty OOP and which can cause some *very* confusing and annoying issues. Wouldn't it be great if we could test to make sure we remember to call `super`? And wouldn't be even better if we could do so automatically?

Well, we can. (This would have have been a very short article otherwise.) Let's take a look at how this works. (Big props to [Lars Anderson](http://theonlylars.com/), who introduced me to this technique in one of our projects. I've borrowed liberally from his code here.)

## Diving In

First off, we'll again create a class for our tests:
	
	#import <objc/runtime.h>
	@interface UIViewController (ViewLifeCycleTesting)
	@end

	@implementation UIViewController (ViewLifeCycleTesting)
	@end
	
	@interface MMViewControllerTests : GHTestCase
	@end

	@implementation MMViewControllerTests
	@end

There are a couple of  interesting things going on here. For one, we're importing the Objective C runtime headers. Because we're going to be manipulating classes within the runtime, we'll need the utility this provides. In addition, we're not only creating a new test class, we're also extending the UIViewController class using Objective C's categories feature. Any UIViewController that gets created will include the additional functionality we will write here. (If you're unfamiliar with Categories, check out [Apple's Docs](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/ProgrammingWithObjectiveC/CustomizingExistingClasses/CustomizingExistingClasses.html).)

When our test case is initialized, we'll want to find all of the classes in our project that are a subclass of UIViewController. This is surprisingly tricky to do in Objective-C. Fortunately, Matt Gallagher has documented a method he wrote called `ClassGetSubclasses` that does the job neatly. It's included in the sample project's code; for more information, see [Matt's blog post](http://www.cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html).

	- (instancetype)init{
	    self = [super init];
	    if (self) {
	        NSArray *subclassesToTest = ClassGetSubclasses([UIViewController class]);
	        [self createTestCasesForClasses:subclassesToTest];
	    }
	    return self;
	}


Now that we've got all of the subclasses of UIViewController, let's create a test for each of the methods we want to be sure calls its super implementation. First we check the first two letters of the class name to make sure that this class starts with "MM" and is therefore one of ours. (Another way to do this would be to have all your view controllers inherit from a common class, and get subclasses of that class instead of UIViewController.)

Then, in order to keep code duplication to a minimum, we'll just write some glue code to enumerate the methods and call a helper method that will actually do the work for us:


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

## Creating The Test Methods

Now, the real work begins! The method below (which we've just called for each of the lifecycle methods we want to test) will sort through the test class' available methods. If the class implements the specified method, will add a test to that class. Don't worry if you don't understand all of this right away; we'll step through it.

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
    
	    if ( implementsSpecifiedSelector ) {
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
            
	            GHAssertTrue(calledSuper,
	                         @"%@ did not call super", NSStringFromSelector(selectorToTest));
	        };
        
	        IMP newMethodIMP = imp_implementationWithBlock(testBlock);
        
	        class_addMethod(self.class, newSelector, newMethodIMP, "v@:");
	    }
	}

So how does this work? First off, we use the runtime library to determine if this class implements the method we're interested in:

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

We call `class_copyMethodList` to get an array of methods. (Apple's runtime API uses C conventions, rather than the OOP design we generally enjoy, so don't worry if this feels like a weird way to do things to you.) We then iterate through the array to see if the selector we're interested in exists or not, and set `implementsSpecifiedSelector` accordingly.

Now if the method *does* exist, we want to add a test method to the class to include the appropriate check. First, we create a new selector for the method we want to create, including both the name of the class being tested and the name of the method we're testing:

	NSString *newSelectorString = [NSString stringWithFormat:@"test%@CallsSuper%@", NSStringFromClass(klass), NSStringFromSelector(selectorToTest)];
	SEL newSelector = NSSelectorFromString(newSelectorString);

## The Test Method Itself

In the previous article, we demonstrated how to use the code from an existing method with our new method. For this example, we'll instead use a block for the test code. (If you're not familiar with blocks, you should go read [Apple's Docs](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/Blocks/Articles/00_Introduction.html) immediately. I'll wait) We'll first declare our testBlock, which takes no parameters and returns nothing:

	void(^testBlock)(void) = ^(void){

Remember that the code we write in this block doesn't actually get executed immediately, but only gets grafted on to the ViewControllerTests object to be executed as a test later. So what will our test code actually look like?

id classInstance = [[klass alloc] init];

Method origMethod = class_getInstanceMethod([klass superclass], selectorToTest);

	SEL selectorToSwizzleIn = @selector(superOverride);
	if (includesParam) {
	    selectorToSwizzleIn = @selector(superOverride:);
	}
	Method newMethod = class_getInstanceMethod([klass superclass], selectorToSwizzleIn);

	method_exchangeImplementations(origMethod, newMethod);

This bit of code is the sneakiest thing about this technique. We grab an instance of the superclass of the class we're testing and swap out the implementation of one of its existing methods (`viewDidLoad`, `viewWillAppear:`, or whichever one we're testing) for one of our own (`superOverride` or `superOverride:`, which we'll write a little later).

`method_exchangeImplementations` does exactly what you'd expect from the name: it swaps the implementations of two methods. Once we use this, calling `superOverride` will run the code that was originally associated with `viewDidLoad` (or whatever we're testing). Conversely, calling `viewDidLoad` will now execute the code that was originally associated with `superOverride`. (Again, we'll actually write that in a minute.)

Once we have our custom code in place at the `viewDidLoad` of the parent class, we'll call the view controller's `view` property to make sure that the view has been instantiated, and then execute the block that calls the appropriate lifecycle method on the class:

	__unused UIView *view;
	@try {
	    view = [classInstance view];
	}
	@catch (NSException *exception) {}

	if (lifecycleTestBlock != nil) {
	    lifecycleTestBlock(classInstance);
	}

Normally Xcode would complain and tell us that the `view` variable never actually gets used for anything. The `__unused` macro prevents it from throwing that warning at us; we're just using it for its side effects since view controllers don't actually instantiate their views until someone asks for them.

In addition, we don't really care if there's an exception while spinning up the view. We're only trying to make sure that we're calling super, so we use the `@try…@catch` block to swallow any issues that occur at that stage.

Finally we call the test block, passing in the class instance that we created so that it can call the appropriate method.

Because we are considerate programmers, the last thing we do is clean up after ourselves and check if our test passed:

	method_exchangeImplementations(newMethod, origMethod);

	GHAssertTrue(calledSuper,
	             @"%@ did not call super", NSStringFromSelector(selectorToTest));

We put the method implementations back where we found them by swapping them again. (You don't want to forget this step. It's *maddening* when calling a method unexpectedly executes code from another.) Then we use `GHAssertTrue` to verify that super was indeed called.

## calledSuper and superOverride

"But what the heck is this `calledSuper` variable? And when are we going to get around to writing those `superOverride` methods you keep promising?"

I'm glad you asked, Rhetorically Convenient Reader! Let's fill those gaps by updating the UIViewController class category we defined way back at the start to read as follows:

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

We declare `calledSuper` as a static variable, which means that it lives independently of the lifecycle of this object. We then implement a very simple `superOverride` method (one with an animated parameter, one without since not all lifecycle methods have that parameter) that simply sets `calledSuper` to YES and continues the method calling chain.

But wait! `superOverride` calls itself! Won't that result in an endless loop? This would absolutely be the case normally. However, remember that this code doesn't get called until its implementation has been swapped with `viewDidLoad` or one of its friends. Thus, when this code is running, calling `[self superOverride]` won't execute this code, but the original `viewDidLoad` code. Neat!

Finally, we also need to set calledSuper to NO at the beginning of each test:

	- (void)setUp{
	    [super setUp];
	    calledSuper = NO;
	}


So here's the whole sequence that happens when the test is run for `viewDidLoad`:

1. setUp sets the static variable `calledSuper` to NO
1. We swap `viewDidLoad` with `superOverride` in the superclass of the view controller being tested
1. We load the view controller's view
1. We call the view controller's `viewDidLoad` method
1. If the view controller calls super like it should, the superclass' `viewDidLoad` method is invoked
1. However, because we swapped their implementations, `superOverride` gets run instead and sets `calledSuper` to YES
1. Our test asserts that `calledSuper` is now YES. If it's not, the test fails.

## Finally Adding the Test

Now we've got our test method finished and stored in `testBlock`. All that remains is to add the method to this `ViewControllerTests` object. (We saw this code in our long listing above, but we'll repeat it here since we've wandered pretty far afield since then.)

	IMP newMethodIMP = imp_implementationWithBlock(testBlock);

	class_addMethod(self.class, newSelector, newMethodIMP, "v@:");

We get a reference to the implementation of `testBlock`, and then use that to add a new method to `ViewControllerTests`, just as we did in the previous article. As you can see, the implementation is the code in our block, and the selector associated with it is the one we set up with the class and method name several paragraphs ago. The `"v@:"` string simply means that the method has no parameters and doesn't return anything. (See Apple's Docs or the first article in this series for more details.)
