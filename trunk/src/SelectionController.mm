/*
 * Copyright (c) 2008 Samuel Gross.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#import "SelectionController.h"


@interface SelectionControllerLeopard : SelectionController
{
  NSInvocation* setCurrentSelection;
  NSInvocation* setColor;
  NSInvocation* setHighlightedSelections;
}
@end

@interface SelectionControllerTiger : SelectionController
{
  NSColor* selectColor;
  NSArray* currentSelection;
  NSMutableArray* highlightedSelections;
}
@end

@implementation SelectionController

- (id)initWithView:(PDFView*)view {
  if (self = [super init]) {
    _view = view;
  }
  return self;
}

+ (SelectionController*)forPDFView:(PDFView*)view
{
  SEL sel = @selector(setCurrentSelection:animate:);
  if ([view respondsToSelector:sel]) {
    return [[[SelectionControllerLeopard alloc] initWithView:view] autorelease];
  } else {
    return [[[SelectionControllerTiger alloc] initWithView:view] autorelease];
  }
}

// "abstract"
- (void)setCurrentSelection:(PDFSelection*)selection {}
- (void)setHighlightedSelections:(NSArray*)selections {}

@end

NSInvocation* invocationForSelector(SEL sel, Class clazz) {
  NSMethodSignature* sig = [clazz instanceMethodSignatureForSelector:sel];
  NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
  [invocation setSelector:sel];
  return invocation;
}

// From PDFViewEdit.m
static NSRect RectPlusScale (NSRect aRect, float scale);

@implementation SelectionControllerLeopard

- (void)dealloc
{
  [setCurrentSelection release];
  [setColor release];
  [setHighlightedSelections release];
  [super dealloc];
}

- (id)initWithView:(PDFView*)view {
  if (self = [super initWithView:view]) {
    setCurrentSelection = [invocationForSelector(@selector(setCurrentSelection:animate:), [PDFView class]) retain];
    BOOL yes = YES;
    [setCurrentSelection setArgument:&yes atIndex:3];
    
    NSColor* yellow = [NSColor yellowColor];
    setColor = [invocationForSelector(@selector(setColor:), [PDFSelection class]) retain];
    [setColor setArgument:&yellow atIndex:2];
    [setColor retainArguments];
    
    setHighlightedSelections = [invocationForSelector(@selector(setHighlightedSelections:), [PDFView class]) retain];
  }
  return self;
}


- (void)setCurrentSelection:(PDFSelection*)selection
{
  
  [_view setCurrentSelection:selection];
  [_view scrollSelectionToVisible:nil];
  [setCurrentSelection setArgument:&selection atIndex:2];
  [setCurrentSelection invokeWithTarget:_view];
}

- (void)setHighlightedSelections:(NSArray*)selections
{
  int count = [selections count];
  for (int i = 0; i < count; i++) {
    PDFSelection* selection = [selections objectAtIndex:i];
    [setColor invokeWithTarget:selection];
  }
  [setHighlightedSelections setArgument:&selections atIndex:2];
  [setHighlightedSelections invokeWithTarget:_view];
}

@end

@implementation SelectionControllerTiger

- (id)initWithView:(PDFView*)view {
  if (self = [super initWithView:view]) {
    selectColor = [[NSColor colorWithDeviceRed:0.22 green:0.85 blue:0.47 alpha:1.0] retain];
    highlightedSelections = [[NSMutableArray arrayWithCapacity:10] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self 
        selector:@selector(mouseDown) name:@"mouseDown" object:_view];
  }
  return self;
}

- (void)dealloc
{
  [selectColor release];
  [currentSelection release];
  [highlightedSelections release];
  [super dealloc];
}

// PDFView doesn't automatically determine annotations need to be 'redisplayed'
- (void)setNeedsDisplay:(PDFAnnotation*)annotation
{
  // From PDFViewEdit.m
  [_view setNeedsDisplayInRect: RectPlusScale([_view convertRect: [annotation bounds]
				fromPage: [annotation page]], [_view scaleFactor])];
}

- (void)removeAnnotations:(NSArray*)array
{
  int count = [array count];
  for (int i = 0; i < count; i++) {
    PDFAnnotation* annotation = [array objectAtIndex:i];
    [[annotation page] removeAnnotation:annotation];
    [self setNeedsDisplay:annotation];
  }
}

- (NSArray*)addAnnotationForSelection:(PDFSelection*)selection color:(NSColor*)color
{
  NSMutableArray* annotations = [NSMutableArray arrayWithCapacity:10];
  NSArray* pages = [selection pages];
  int count = [pages count];
  for (int i = 0; i < count; i++) {
    PDFPage* page = [pages objectAtIndex:i];
    NSRect bounds = [selection boundsForPage:page];
    PDFAnnotation* annotation = [[PDFAnnotationMarkup alloc] initWithBounds:bounds]; 
    [annotation setColor:color];
    [page addAnnotation:annotation];
    [annotations addObject:annotation];
    [self setNeedsDisplay:annotation];
  }
  return annotations;
}

- (void)setCurrentSelection:(PDFSelection*)selection
{
  if (currentSelection) {
    [self removeAnnotations:currentSelection];
    [currentSelection release];
    currentSelection = nil;
  }
  if (selection) {
    currentSelection = [[self addAnnotationForSelection:selection color:selectColor] retain];
  }
  [_view setCurrentSelection:selection];
  [_view scrollSelectionToVisible:nil];
}

- (void)setHighlightedSelections:(NSArray*)selections
{
  [self removeAnnotations:highlightedSelections];
  [highlightedSelections removeAllObjects];
  
  if (selections) {
    int count = [selections count];
    for (int i = 0; i < count; i++) {
      PDFSelection* selection = [selections objectAtIndex:i];
      NSArray* annotations = [self addAnnotationForSelection:selection color:[NSColor yellowColor]];
      [highlightedSelections addObjectsFromArray:annotations];
    }
  }
}

- (void)mouseDown
{
  if (currentSelection) {
    [self removeAnnotations:currentSelection];
    [currentSelection release];
    currentSelection = nil;
  }
}

@end

// From PDFViewEdit.m in Apple's PDF Annotation Editor example
static NSRect RectPlusScale (NSRect aRect, float scale)
{
	float		maxX;
	float		maxY;
	NSPoint		origin;
	
	// Determine edges.
	maxX = ceilf(aRect.origin.x + aRect.size.width) + scale;
	maxY = ceilf(aRect.origin.y + aRect.size.height) + scale;
	origin.x = floorf(aRect.origin.x) - scale;
	origin.y = floorf(aRect.origin.y) - scale;
	
	return NSMakeRect(origin.x, origin.y, maxX - origin.x, maxY - origin.y);
}
