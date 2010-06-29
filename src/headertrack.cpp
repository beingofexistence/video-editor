/***************************************************************************
 *   Copyright (C) 2008 by Jean-Baptiste Mardelle (jb@kdenlive.org)        *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA          *
 ***************************************************************************/


#include "headertrack.h"

#include <KIcon>
#include <KLocale>
#include <KDebug>
#include <KColorScheme>

#include <QMouseEvent>
#include <QWidget>
#include <QPainter>
#include <QAction>
#include <QTimer>
#include <QColor>

HeaderTrack::HeaderTrack(int index, TrackInfo info, int height, QWidget *parent) :
        QWidget(parent),
        m_index(index),
        m_type(info.type),
        m_isSelected(false)
{
    setFixedHeight(height);
    setupUi(this);
    QColor col = track_number->palette().color(QPalette::Base);
    track_number->setStyleSheet(QString("QLineEdit { background-color: transparent;} QLineEdit:hover{ background-color: rgb(%1, %2, %3);} QLineEdit:focus { background-color: rgb(%1, %2, %3);}").arg(col.red()).arg(col.green()).arg(col.blue()));

    m_name = info.trackName.isEmpty() ? QString::number(m_index) : info.trackName;
    track_number->setText(m_name);
    connect(track_number, SIGNAL(editingFinished()), this, SLOT(slotRenameTrack()));

    buttonVideo->setChecked(info.isBlind);
    buttonVideo->setToolTip(i18n("Hide track"));
    buttonAudio->setChecked(info.isMute);
    buttonAudio->setToolTip(i18n("Mute track"));
    buttonLock->setChecked(info.isLocked);
    buttonLock->setToolTip(i18n("Lock track"));

    QPalette p = palette();
    KColorScheme scheme(p.currentColorGroup(), KColorScheme::Window);
    p.setColor(QPalette::Button, scheme.background(KColorScheme::ActiveBackground).color().darker(120));
    setPalette(p);

    if (m_type == VIDEOTRACK) {
        setBackgroundRole(QPalette::AlternateBase);
        setAutoFillBackground(true);
        if (!info.isBlind)
            buttonVideo->setIcon(KIcon("kdenlive-show-video"));
        else
            buttonVideo->setIcon(KIcon("kdenlive-hide-video"));
    } else {
        buttonVideo->setHidden(true);
    }
    if (!info.isMute)
        buttonAudio->setIcon(KIcon("kdenlive-show-audio"));
    else
        buttonAudio->setIcon(KIcon("kdenlive-hide-audio"));

    if (!info.isLocked)
        buttonLock->setIcon(KIcon("kdenlive-unlock"));
    else
        buttonLock->setIcon(KIcon("kdenlive-lock"));

    connect(buttonVideo, SIGNAL(clicked()), this, SLOT(switchVideo()));
    connect(buttonAudio, SIGNAL(clicked()), this, SLOT(switchAudio()));
    connect(buttonLock, SIGNAL(clicked()), this, SLOT(switchLock()));

    // Don't show track buttons if size is too small
    if (height < 40) {
        buttonVideo->setHidden(true);
        buttonAudio->setHidden(true);
        buttonLock->setHidden(true);
        //horizontalSpacer;
    }

    setContextMenuPolicy(Qt::DefaultContextMenu); //Qt::ActionsContextMenu);
    QAction *insertAction = new QAction(i18n("Insert Track"), this);
    m_menu.addAction(insertAction);
    connect(insertAction, SIGNAL(triggered()), this, SLOT(slotAddTrack()));

    QAction *removeAction = new QAction(KIcon("edit-delete"), i18n("Delete Track"), this);
    m_menu.addAction(removeAction);
    connect(removeAction, SIGNAL(triggered()), this, SLOT(slotDeleteTrack()));

    QAction *configAction = new QAction(KIcon("configure"), i18n("Configure Track"), this);
    m_menu.addAction(configAction);
    connect(configAction, SIGNAL(triggered()), this, SLOT(slotConfigTrack()));
}

/*HeaderTrack::~HeaderTrack()
{
}*/

// virtual
void HeaderTrack::mousePressEvent(QMouseEvent * event)
{
    if (track_number->hasFocus()) {
        track_number->clearFocus();
        return;
    }
    if (!m_isSelected) emit selectTrack(m_index);
    QWidget::mousePressEvent(event);
}

// virtual
void HeaderTrack::contextMenuEvent(QContextMenuEvent * event)
{
    if (track_number->hasFocus()) {
        track_number->clearFocus();
        return;
    }
    m_menu.popup(event->globalPos());
}

void HeaderTrack::mouseDoubleClickEvent(QMouseEvent* event)
{
    if (track_number->hasFocus()) {
        track_number->clearFocus();
        return;
    }
    slotConfigTrack();
    QWidget::mouseDoubleClickEvent(event);
}

void HeaderTrack::setSelectedIndex(int ix)
{
    if (m_index == ix) {
        m_isSelected = true;
        setBackgroundRole(QPalette::Button);
        setAutoFillBackground(true);
    } else if (m_type != VIDEOTRACK) {
        m_isSelected = false;
        setAutoFillBackground(false);
    } else {
        m_isSelected = false;
        setBackgroundRole(QPalette::AlternateBase);
    }
    update();
}

void HeaderTrack::adjustSize(int height)
{
    // Don't show track buttons if size is too small
    bool smallTracks = height < 40;
    if (m_type == VIDEOTRACK)
        buttonVideo->setHidden(smallTracks);
    buttonAudio->setHidden(smallTracks);
    buttonLock->setHidden(smallTracks);
    setFixedHeight(height);
}

void HeaderTrack::switchVideo()
{
    if (buttonVideo->isChecked())
        buttonVideo->setIcon(KIcon("kdenlive-hide-video"));
    else
        buttonVideo->setIcon(KIcon("kdenlive-show-video"));
    emit switchTrackVideo(m_index);
}

void HeaderTrack::switchAudio()
{
    if (buttonAudio->isChecked())
        buttonAudio->setIcon(KIcon("kdenlive-hide-audio"));
    else
        buttonAudio->setIcon(KIcon("kdenlive-show-audio"));
    emit switchTrackAudio(m_index);
}

void HeaderTrack::switchLock(bool emitSignal)
{
    if (buttonLock->isChecked())
        buttonLock->setIcon(KIcon("kdenlive-lock"));
    else
        buttonLock->setIcon(KIcon("kdenlive-unlock"));
    if (emitSignal)
        emit switchTrackLock(m_index);
}

void HeaderTrack::setLock(bool lock)
{
    buttonLock->setChecked(lock);
    switchLock(false);
}

void HeaderTrack::slotDeleteTrack()
{
    QTimer::singleShot(500, this, SLOT(deleteTrack()));
}

void HeaderTrack::deleteTrack()
{
    emit deleteTrack(m_index);
}

void HeaderTrack::slotAddTrack()
{
    emit insertTrack(m_index);
}

void HeaderTrack::slotRenameTrack()
{
    if (m_name != track_number->text()) emit renameTrack(m_index, track_number->text());
}

void HeaderTrack::slotConfigTrack()
{
    emit configTrack(m_index);
}


#include "headertrack.moc"
