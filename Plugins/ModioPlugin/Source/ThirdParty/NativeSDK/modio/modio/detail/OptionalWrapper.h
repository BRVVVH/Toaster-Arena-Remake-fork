/*
 *  Copyright (C) 2021 mod.io Pty Ltd. <https://mod.io>
 *
 *  This file is part of the mod.io SDK.
 *
 *  Distributed under the MIT License. (See accompanying file LICENSE or
 *   view online at <https://github.com/modio/modio-sdk/blob/main/LICENSE>)
 *
 */

#pragma once

#if defined(MODIO_PLATFORM_UNREAL)

	#include MODIO_UNREAL_PLATFORM_PREAMBLE
	#include "modio/detail/ModioCompilerMacros.h"

	DISABLE_WARNING_PUSH
	DISABLE_WARNING_NOT_IMPLICIT_CONSTRUCTOR
	DISABLE_WARNING_NOT_IMPLICIT_DESCTRUCTOR

	#include "tl/optional.hpp"

	DISABLE_WARNING_POP

	#include MODIO_UNREAL_PLATFORM_EPILOGUE

#elif defined(__GNUC__) || defined(__clang__)

	#include "modio/detail/ModioCompilerMacros.h"

	DISABLE_WARNING_PUSH
	DISABLE_WARNING_SIGNED_UNSIGNED_INTEGER_COMPARISON

	#include "tl/optional.hpp"

	DISABLE_WARNING_POP

#else

	#include "tl/optional.hpp"

#endif
