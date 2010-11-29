/*
  ==============================================================================

   This file is part of the JUCE library - "Jules' Utility Class Extensions"
   Copyright 2004-10 by Raw Material Software Ltd.

  ------------------------------------------------------------------------------

   JUCE can be redistributed and/or modified under the terms of the GNU General
   Public License (Version 2), as published by the Free Software Foundation.
   A copy of the license is included in the JUCE distribution, or can be found
   online at www.gnu.org/licenses.

   JUCE is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
   A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  ------------------------------------------------------------------------------

   To release a closed-source product which uses JUCE, commercial licenses are
   available: visit www.rawmaterialsoftware.com/juce for more information.

  ==============================================================================
*/

#ifndef __JUCE_MEMORY_JUCEHEADER__
#define __JUCE_MEMORY_JUCEHEADER__

//==============================================================================
/*
    This file defines the various juce_malloc(), juce_free() macros that should be used in
    preference to the standard calls.
*/

#if JUCE_MSVC && JUCE_CHECK_MEMORY_LEAKS
  #ifndef JUCE_DLL
    //==============================================================================
    // Win32 debug non-DLL versions..

    /** This should be used instead of calling malloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_malloc(numBytes)                 _malloc_dbg  (numBytes, _NORMAL_BLOCK, __FILE__, __LINE__)

    /** This should be used instead of calling calloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_calloc(numBytes)                 _calloc_dbg  (1, numBytes, _NORMAL_BLOCK, __FILE__, __LINE__)

    /** This should be used instead of calling realloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_realloc(location, numBytes)      _realloc_dbg (location, numBytes, _NORMAL_BLOCK, __FILE__, __LINE__)

    /** This should be used instead of calling free directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_free(location)                   _free_dbg    (location, _NORMAL_BLOCK)

  #else
    //==============================================================================
    // Win32 debug DLL versions..

    // For the DLL, we'll define some functions in the DLL that will be used for allocation - that
    // way all juce calls in the DLL and in the host API will all use the same allocator.
    extern JUCE_API void* juce_DebugMalloc (const int size, const char* file, const int line);
    extern JUCE_API void* juce_DebugCalloc (const int size, const char* file, const int line);
    extern JUCE_API void* juce_DebugRealloc (void* const block, const int size, const char* file, const int line);
    extern JUCE_API void juce_DebugFree (void* const block);

    /** This should be used instead of calling malloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_malloc(numBytes)                 JUCE_NAMESPACE::juce_DebugMalloc (numBytes, __FILE__, __LINE__)

    /** This should be used instead of calling calloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_calloc(numBytes)                 JUCE_NAMESPACE::juce_DebugCalloc (numBytes, __FILE__, __LINE__)

    /** This should be used instead of calling realloc directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_realloc(location, numBytes)      JUCE_NAMESPACE::juce_DebugRealloc (location, numBytes, __FILE__, __LINE__)

    /** This should be used instead of calling free directly.
        Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
    */
    #define juce_free(location)                   JUCE_NAMESPACE::juce_DebugFree (location)
  #endif

#elif defined (JUCE_DLL)
  //==============================================================================
  // Win32 DLL (release) versions..

  // For the DLL, we'll define some functions in the DLL that will be used for allocation - that
  // way all juce calls in the DLL and in the host API will all use the same allocator.
  extern JUCE_API void* juce_Malloc (const int size);
  extern JUCE_API void* juce_Calloc (const int size);
  extern JUCE_API void* juce_Realloc (void* const block, const int size);
  extern JUCE_API void juce_Free (void* const block);

  /** This should be used instead of calling malloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_malloc(numBytes)                 JUCE_NAMESPACE::juce_Malloc (numBytes)

  /** This should be used instead of calling calloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_calloc(numBytes)                 JUCE_NAMESPACE::juce_Calloc (numBytes)

  /** This should be used instead of calling realloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_realloc(location, numBytes)      JUCE_NAMESPACE::juce_Realloc (location, numBytes)

  /** This should be used instead of calling free directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_free(location)                   JUCE_NAMESPACE::juce_Free (location)

#else

  //==============================================================================
  // Mac, Linux and Win32 (release) versions..

  /** This should be used instead of calling malloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_malloc(numBytes)                 malloc (numBytes)

  /** This should be used instead of calling calloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_calloc(numBytes)                 calloc (1, numBytes)

  /** This should be used instead of calling realloc directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_realloc(location, numBytes)      realloc (location, numBytes)

  /** This should be used instead of calling free directly.
      Only use direct memory allocation if there's really no way to use a HeapBlock object instead!
  */
  #define juce_free(location)                   free (location)

#endif

//==============================================================================
/** (Deprecated) This was a win32-specific way of checking for object leaks - now please
    use the JUCE_LEAK_DETECTOR instead.
*/
#ifndef juce_UseDebuggingNewOperator
  #define juce_UseDebuggingNewOperator
#endif

//==============================================================================
#if JUCE_MSVC || DOXYGEN
  /** This is a compiler-independent way of declaring a variable as being thread-local.

      E.g.
      @code
      juce_ThreadLocal int myVariable;
      @endcode
  */
  #define juce_ThreadLocal    __declspec(thread)
#else
  #define juce_ThreadLocal    __thread
#endif

//==============================================================================
#if JUCE_MINGW
  /** This allocator is not defined in mingw gcc. */
  #define alloca              __builtin_alloca
#endif

//==============================================================================
/** Clears a block of memory. */
inline void zeromem (void* memory, size_t numBytes) throw()         { memset (memory, 0, numBytes); }

/** Clears a reference to a local structure. */
template <typename Type>
inline void zerostruct (Type& structure) throw()                    { memset (&structure, 0, sizeof (structure)); }

/** A handy function that calls delete on a pointer if it's non-zero, and then sets
    the pointer to null.

    Never use this if there's any way you could use a ScopedPointer or other safer way of
    managing the lieftimes of your objects!
*/
template <typename Type>
inline void deleteAndZero (Type& pointer)                           { delete pointer; pointer = 0; }

/** A handy function which adds a number of bytes to any type of pointer and returns the result.
    This can be useful to avoid casting pointers to a char* and back when you want to move them by
    a specific number of bytes,
*/
template <typename Type>
inline Type* addBytesToPointer (Type* pointer, int bytes) throw()   { return (Type*) (((char*) pointer) + bytes); }


#endif   // __JUCE_MEMORY_JUCEHEADER__
