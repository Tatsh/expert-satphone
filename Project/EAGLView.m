#import "EAGLView.h"

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <QuartzCore/QuartzCore.h>

@interface EAGLView ()

// The set of touches currently down, accumulated across frames.
@property(nonatomic, strong) NSMutableSet *currentTouches;
// Touches released since the last frame, drained by -touches.
@property(nonatomic, strong) NSMutableSet *releaseTouches;

@end

// The shared quad index buffer maps a run of quad vertices to two triangles each. Every quad
// contributes four vertices and six indices (two triangles), so the buffer holds
// (kMaxQuadVertexCount / kQuadVertexStride) * kQuadIndexStride indices.
enum {
    kMaxQuadVertexCount = 4096, // Upper bound on quad vertices the shared index buffer covers.
    kQuadVertexStride = 4,      // Vertices consumed by one quad.
    kQuadIndexStride = 6,       // Indices emitted for one quad (two triangles).
    kInitialTouchCapacity = 16, // Initial capacity of the touch-tracking sets.
};

@implementation EAGLView {
    GLint backingWidth;
    GLint backingHeight;
    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;
    GLuint elementArrayBuffer;
}

#pragma mark - Layer

/** @ghidraAddress 0xca80 */
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xca94 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking : @YES,
            kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
        };
        self.renderContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if (self.renderContext && [EAGLContext setCurrentContext:self.renderContext]) {
            _currentTouches = [NSMutableSet setWithCapacity:kInitialTouchCapacity];
            _releaseTouches = [NSMutableSet setWithCapacity:kInitialTouchCapacity];
        } else {
            self = nil;
        }
    }
    return self;
}

/** @ghidraAddress 0xdb24 */
- (void)dealloc {
    [self destroyFramebuffer];
    [EAGLContext setCurrentContext:nil];
}

#pragma mark - Context

/** @ghidraAddress 0xcd50 */
- (void)startRenderContext {
    [EAGLContext setCurrentContext:self.renderContext];
}

/** @ghidraAddress 0xcda0 */
- (void)performBlockInBackground:(void (^)(void))block {
    EAGLContext *renderContext = self.renderContext;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0xce88 */
      // A second context sharing the render context's sharegroup, so GL resources uploaded on
      // this queue are visible to the main context.
      EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1
                                                   sharegroup:renderContext.sharegroup];
      [EAGLContext setCurrentContext:context];
      block();
      [EAGLContext setCurrentContext:nil];
    });
}

#pragma mark - Rendering

/** @ghidraAddress 0xcf98 */
- (void)prepareToRender {
    [EAGLContext setCurrentContext:self.renderContext];
    if (defaultFramebuffer != 0) {
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    }
}

/** @ghidraAddress 0xd024 */
- (void)swapBuffer {
    if (defaultFramebuffer != 0) {
        const GLenum discards[] = {GL_DEPTH_ATTACHMENT_OES};
        glDiscardFramebufferEXT(GL_FRAMEBUFFER_OES, 1, discards);
        glGetError(); // The binary discards this result.
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
        [self.renderContext presentRenderbuffer:GL_RENDERBUFFER_OES];
    }
}

/** @ghidraAddress 0xd0b8 */
- (BOOL)createFramebuffer {
    [EAGLContext setCurrentContext:self.renderContext];
    glGenFramebuffersOES(1, &defaultFramebuffer);
    glGenRenderbuffersOES(1, &colorRenderbuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [self.renderContext renderbufferStorage:GL_RENDERBUFFER_OES
                               fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(
        GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    glGenRenderbuffersOES(1, &depthRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
    glRenderbufferStorageOES(
        GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
    glFramebufferRenderbufferOES(
        GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
    if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        return NO;
    }
    glViewport(0, 0, backingWidth, backingHeight);
    glScissor(0, 0, backingWidth, backingHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glScalef(1.0f, -1.0f, 1.0f);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    const size_t indexBufferSize =
        (kMaxQuadVertexCount / kQuadVertexStride) * kQuadIndexStride * sizeof(GLushort);
    GLushort *indices = (GLushort *)malloc(indexBufferSize);
    GLushort *cursor = indices;
    for (GLushort base = 0; base < kMaxQuadVertexCount; base += kQuadVertexStride) {
        cursor[0] = base;
        cursor[1] = base + 1;
        cursor[2] = base + 2;
        cursor[3] = base + 2;
        cursor[4] = base + 1;
        cursor[5] = base + 3;
        cursor += kQuadIndexStride;
    }
    glGenBuffers(1, &elementArrayBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementArrayBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBufferSize, indices, GL_STATIC_DRAW);
    free(indices);
    glEnable(GL_TEXTURE_2D);
    return YES;
}

/** @ghidraAddress 0xd3c8 */
- (void)destroyFramebuffer {
    [EAGLContext setCurrentContext:self.renderContext];
    if (defaultFramebuffer != 0) {
        glDeleteFramebuffersOES(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }
    if (colorRenderbuffer != 0) {
        glDeleteRenderbuffersOES(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    if (depthRenderbuffer != 0) {
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
    if (elementArrayBuffer != 0) {
        glDeleteBuffers(1, &elementArrayBuffer);
        elementArrayBuffer = 0;
    }
}

/** @ghidraAddress 0xd4b8 */
- (void)set2dSpace:(CGSize)size {
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0.0f, (float)size.width, -(float)size.height, 0.0f, -2.0f, 2.0f);
}

/** @ghidraAddress 0xd500 */
- (void)layoutSubviews {
}

#pragma mark - Touches

/** @ghidraAddress 0xd504 */
- (NSMutableSet *)touches {
    NSMutableSet *touches = [NSMutableSet setWithSet:self.currentTouches];
    for (UITouch *touch in self.releaseTouches) {
        [touches addObject:touch];
    }
    [self.releaseTouches removeAllObjects];
    return touches;
}

/** @ghidraAddress 0xd6b4 */
- (void)resetTouches {
    [self.currentTouches removeAllObjects];
    [self.releaseTouches removeAllObjects];
}

/** @ghidraAddress 0xd730 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if (![self.currentTouches containsObject:touch]) {
            [self.currentTouches addObject:touch];
        }
    }
}

/** @ghidraAddress 0xd8c0 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
}

/** @ghidraAddress 0xd8c4 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if ([self.currentTouches containsObject:touch]) {
            [self.currentTouches removeObject:touch];
            if (![self.releaseTouches containsObject:touch]) {
                [self.releaseTouches addObject:touch];
            }
        }
    }
}

/** @ghidraAddress 0xdad4 */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

@end
