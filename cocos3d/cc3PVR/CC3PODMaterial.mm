/*
 * CC3PODMaterial.mm
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2010-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
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
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3PODMaterial.h for full API documentation.
 */

extern "C" {
	#import "CC3Foundation.h"	// extern must be first, since foundation also imported via other imports
}
#import "CC3PODMaterial.h"
#import "CC3PVRTModelPOD.h"
#import "CC3PFXResource.h"

@interface CC3PODMaterial (TemplateMethods)
-(void) addTexture: (GLint) aPODTexIndex fromPODResource: (CC3PODResource*) aPODRez;
-(void) addBumpMapTexture: (GLint) aPODTexIndex fromPODResource: (CC3PODResource*) aPODRez;
@end

@implementation CC3PODMaterial

@synthesize pfxEffect=_pfxEffect;

-(GLint) podIndex { return _podIndex; }

-(void) setPodIndex: (GLint) aPODIndex { _podIndex = aPODIndex; }

static GLfloat shininessExpansionFactor = 128.0f;

+(GLfloat) shininessExpansionFactor { return shininessExpansionFactor; }

+(void) setShininessExpansionFactor: (GLfloat) aFloat { shininessExpansionFactor = aFloat; }

-(id) initAtIndex: (GLint) aPODIndex fromPODResource: (CC3PODResource*) aPODRez {
	SPODMaterial* psm = (SPODMaterial*)[aPODRez materialPODStructAtIndex: aPODIndex];
	LogRez(@"Creating %@ at index %i from: %@", [self class], aPODIndex, NSStringFromSPODMaterial(psm));
	if ( (self = [super initWithName: [NSString stringWithUTF8String: psm->pszName]]) ) {
		self.podIndex = aPODIndex;
		self.ambientColor = ccc4f(psm->pfMatAmbient[0], psm->pfMatAmbient[1], psm->pfMatAmbient[2], psm->fMatOpacity);
		self.diffuseColor = ccc4f(psm->pfMatDiffuse[0], psm->pfMatDiffuse[1], psm->pfMatDiffuse[2], psm->fMatOpacity);
		self.specularColor = ccc4f(psm->pfMatSpecular[0], psm->pfMatSpecular[1], psm->pfMatSpecular[2], psm->fMatOpacity);
		self.shininess = psm->fMatShininess * shininessExpansionFactor;
		self.sourceBlend = GLBlendFuncFromEPODBlendFunc(psm->eBlendSrcA);
		self.destinationBlend = GLBlendFuncFromEPODBlendFunc(psm->eBlendDstA);

		// Add the bump-map texture first, then add the remaining in order.
		// Textures are only added if they are in the POD file.
		[self addBumpMapTexture: psm->nIdxTexBump fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexDiffuse fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexAmbient fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexSpecularColour fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexSpecularLevel fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexEmissive fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexGlossiness fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexOpacity fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexReflection fromPODResource: aPODRez];
		[self addTexture: psm->nIdxTexRefraction fromPODResource: aPODRez];
		
		if (psm->pszEffectName && psm->pszEffectFile) {
			_pfxEffect = [aPODRez.pfxResourceClass getEffectNamed: [NSString stringWithUTF8String: psm->pszEffectName]
												inPFXResourceFile: [NSString stringWithUTF8String: psm->pszEffectFile]];
			[_pfxEffect populateMaterial: self];
		}
		
		// Assign any user data and take ownership of managing its memory
		if (psm->pUserData && psm->nUserDataSize > 0) {
			self.userData = [NSData dataWithBytesNoCopy: psm->pUserData length: psm->nUserDataSize];
			psm->pUserData = NULL;		// Clear reference so SPODNode won't try to free it.
		}
	}
	return self;
}

+(id) materialAtIndex: (GLint) aPODIndex fromPODResource: (CC3PODResource*) aPODRez {
	return [[self alloc] initAtIndex: aPODIndex fromPODResource: aPODRez];
}

-(void) populateFrom: (CC3PODMaterial*) another {
	[super populateFrom: another];

	_podIndex = another.podIndex;
}

/**
 * If the specified texture index is valid, extracts the texture from the POD resource
 * and adds it to this material.
 */
-(void) addTexture: (GLint) aPODTexIndex fromPODResource: (CC3PODResource*) aPODRez {
	if (aPODTexIndex >= 0 && aPODTexIndex < (GLint)aPODRez.textureCount) {
		[self addTexture: [aPODRez textureAtIndex: aPODTexIndex]];
	}
}

/**
 * If the specified texture index is valid, extracts the texture from the POD resource,
 * configures it as a bump-map texture, and adds it to this material.
 */
-(void) addBumpMapTexture: (GLint) aPODTexIndex fromPODResource: (CC3PODResource*) aPODRez {
	if (aPODTexIndex >= 0 && aPODTexIndex < (GLint)aPODRez.textureCount) {
		CC3Texture* tex = [aPODRez textureAtIndex: aPODTexIndex];
		CC3TextureUnitTexture* bmTex = [CC3TextureUnitTexture textureWithTexture: tex];
		bmTex.textureUnit = [CC3BumpMapTextureUnit textureUnit];
		[self addTexture: bmTex];
	}
}

@end
