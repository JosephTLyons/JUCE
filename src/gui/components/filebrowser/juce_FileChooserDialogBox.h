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

#ifndef __JUCE_FILECHOOSERDIALOGBOX_JUCEHEADER__
#define __JUCE_FILECHOOSERDIALOGBOX_JUCEHEADER__

#include "juce_FileBrowserComponent.h"
#include "../windows/juce_ResizableWindow.h"
#include "../buttons/juce_TextButton.h"
#include "../../graphics/fonts/juce_GlyphArrangement.h"


//==============================================================================
/**
    A file open/save dialog box.

    This is a Juce-based file dialog box; to use a native file chooser, see the
    FileChooser class.

    To use one of these, create it and call its show() method. e.g.

    @code
    {
        WildcardFileFilter wildcardFilter ("*.foo", "Foo files");

        FileBrowserComponent browser (FileBrowserComponent::loadFileMode,
                                      File::nonexistent,
                                      &wildcardFilter,
                                      0);

        FileChooserDialogBox dialogBox ("Open some kind of file",
                                        "Please choose some kind of file that you want to open...",
                                        browser,
                                        getLookAndFeel().alertWindowBackground);

        if (dialogBox.show())
        {
            File selectedFile = browser.getCurrentFile();
            ...
        }
    }
    @endcode

    @see FileChooser
*/
class JUCE_API  FileChooserDialogBox : public ResizableWindow,
                                       public ButtonListener,  // (can't use Button::Listener due to idiotic VC2005 bug)
                                       public FileBrowserListener
{
public:
    //==============================================================================
    /** Creates a file chooser box.

        @param title            the main title to show at the top of the box
        @param instructions     an optional longer piece of text to show below the title in
                                a smaller font, describing in more detail what's required.
        @param browserComponent a FileBrowserComponent that will be shown inside this dialog
                                box. Make sure you delete this after (but not before!) the
                                dialog box has been deleted.
        @param warnAboutOverwritingExistingFiles     if true, then the user will be asked to confirm
                                if they try to select a file that already exists. (This
                                flag is only used when saving files)
        @param backgroundColour the background colour for the top level window

        @see FileBrowserComponent, FilePreviewComponent
    */
    FileChooserDialogBox (const String& title,
                          const String& instructions,
                          FileBrowserComponent& browserComponent,
                          bool warnAboutOverwritingExistingFiles,
                          const Colour& backgroundColour);

    /** Destructor. */
    ~FileChooserDialogBox();

    //==============================================================================
    /** Displays and runs the dialog box modally.

        This will show the box with the specified size, returning true if the user
        pressed 'ok', or false if they cancelled.

        Leave the width or height as 0 to use the default size
    */
    bool show (int width = 0, int height = 0);

    /** Displays and runs the dialog box modally.

        This will show the box with the specified size at the specified location,
        returning true if the user pressed 'ok', or false if they cancelled.

        Leave the width or height as 0 to use the default size.
    */
    bool showAt (int x, int y, int width, int height);

    //==============================================================================
    /** A set of colour IDs to use to change the colour of various aspects of the box.

        These constants can be used either via the Component::setColour(), or LookAndFeel::setColour()
        methods.

        @see Component::setColour, Component::findColour, LookAndFeel::setColour, LookAndFeel::findColour
    */
    enum ColourIds
    {
        titleTextColourId      = 0x1000850, /**< The colour to use to draw the box's title. */
    };

    //==============================================================================
    /** @internal */
    void buttonClicked (Button* button);
    /** @internal */
    void closeButtonPressed();
    /** @internal */
    void selectionChanged();
    /** @internal */
    void fileClicked (const File& file, const MouseEvent& e);
    /** @internal */
    void fileDoubleClicked (const File& file);

private:
    class ContentComponent  : public Component
    {
    public:
        ContentComponent (const String& name, const String& instructions, FileBrowserComponent& chooserComponent);
        ~ContentComponent();

        void paint (Graphics& g);
        void resized();

        String instructions;
        GlyphArrangement text;

        FileBrowserComponent& chooserComponent;
        TextButton okButton, cancelButton;
    };

    ContentComponent* content;
    const bool warnAboutOverwritingExistingFiles;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (FileChooserDialogBox);
};


#endif   // __JUCE_FILECHOOSERDIALOGBOX_JUCEHEADER__
