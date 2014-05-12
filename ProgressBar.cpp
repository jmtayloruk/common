/*	Module: ProgressBar.cpp

	Code to display a progress bar for time-consuming operations.
	TextualProgressBar writes a growing line to stdout
	ProgressWindow (see separate file) displays a window showing a progress bar and
	indicating time taken, time remaining etc.	*/
	
#include <stdarg.h>
#include <algorithm>

#include "jCommon.h"
#include "jTimeUtils.h"
#include "ProgressBar.h"

long BaseProgressBar::disabled = 0;

BaseProgressBar::BaseProgressBar(double inLength)
{
	currentProgress = 0;
	length = inLength;
	reportElapsedTime = false;
	overrideEnabled = false;
	startTime = GetTime();
	ResetTimeEstimate();
}

BaseProgressBar::~BaseProgressBar()
{
	if ((reportElapsedTime) && Enabled())
	{
		double endTime;
		endTime = GetTime();
		ReportElapsedTime(startTime, endTime, "time taken");		
	}
}

void BaseProgressBar::UpdateLength(double newLength)
{
	length = newLength;
}

void BaseProgressBar::UpdateProgress(double newProgress)
{
	LocalGetMutex lgm(&progressMutex);
	InternalUpdateProgress(newProgress);
}

void BaseProgressBar::DeltaProgress(double delta)
{
	LocalGetMutex lgm(&progressMutex);
	InternalUpdateProgress(currentProgress + delta);
}

void BaseProgressBar::GetElapsedTime(int *hours, int *mins, double *secs)
{
	double curTime = GetTime();
	*secs = CalcElapsedSecs(startTime, curTime);
	*hours = (int)(*secs / 3600);
	*secs -= *hours * 3600;
	*mins = (int)(*secs / 60);
	*secs -= *mins * 60;
}

void BaseProgressBar::ResetTimeEstimate(void)
{
	startTimeForEstimate = GetTime();
	startingProgressForEstimate = currentProgress;
}

void BaseProgressBar::EstimateTimeRemaining(int *hours, int *mins, double *secs)
{
	double curTime = GetTime();
	*secs = CalcElapsedSecs(startTimeForEstimate, curTime) * ((length - startingProgressForEstimate) / (currentProgress - startingProgressForEstimate) - 1.0);
	*hours = (int)(*secs / 3600);
	*secs -= *hours * 3600;
	*mins = (int)(*secs / 60);
	*secs -= *mins * 60;
}

const char *TextualProgressBar::kTextProgressBarSpaces = "                                                  ";
const long TextualProgressBar::kTextProgressBarWidth = strlen(TextualProgressBar::kTextProgressBarSpaces);

TextualProgressBar::TextualProgressBar(const char *title, double inLength, ...) : BaseProgressBar(inLength)
{
	va_list		argList;
	va_start(argList, inLength);
	drawnTitle = false;
	if (title != NULL)
		SetTitle(title, argList);
	numCharsDrawn = 0;
}

void TextualProgressBar::OverrideEnable(void)
{
	BaseProgressBar::OverrideEnable();
	SetTitle("");
}

void TextualProgressBar::SetTitle(const char *title, ...)
{
	va_list		argList;
	va_start(argList, title);
	SetTitle(title, argList);
}

void TextualProgressBar::SetTitle(const char *title, va_list argList)
{
	if (title != NULL)
		vsnprintf(cachedTitle, sizeof(cachedTitle), title, argList);
		
	if (Enabled() && !drawnTitle)
	{
		printf("%s", cachedTitle);
		printf(" |%s|\n", kTextProgressBarSpaces);
	
		const char	*lastTitleLine = cachedTitle;
		while (strchr(lastTitleLine, '\n') != NULL)
			lastTitleLine = strchr(lastTitleLine, '\n') + 1;
			
		for (long i = strlen(lastTitleLine) + 2; i > 0; i--)
			printf(" ");
		drawnTitle = true;
	}
}

void TextualProgressBar::InternalUpdateProgress(double newProgress)
{
	newProgress = MIN(newProgress, length);
	
	if (Enabled())
	{
		long	numCharsRequired = (long)((newProgress / length) * kTextProgressBarWidth);
		if (numCharsRequired > numCharsDrawn)
		{
			for (long i = 0; i < (numCharsRequired - numCharsDrawn); i++)
				printf("-");
			fflush(stdout);
			numCharsDrawn = numCharsRequired;
		}
	}

	currentProgress = newProgress;	
}
