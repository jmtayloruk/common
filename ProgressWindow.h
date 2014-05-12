#ifndef __PROGRESSWINDOW_H__
#define __PROGRESSWINDOW_H__

#include "ProgressBar.h"

#if 0//HAS_OS_X_GUI
class ProgressWindow : public BaseProgressBar
{
  protected:
	WindowRef		theWindow;
	long			windowWidth, windowHeight;
	
	virtual void	InternalUpdateProgress(double newProgress);

  public:
					ProgressWindow(long x, long y, const char *title, double inLength, ...) __attribute__ ((format (printf, 4, 6)));
	virtual			~ProgressWindow();
};
#else
class ProgressWindow : public TextualProgressBar
{
  public:
					ProgressWindow(long x, long y, const char *title, double inLength, ...) __attribute__ ((format (printf, 4, 6)));
	virtual			~ProgressWindow() { }
};
#endif

#endif
