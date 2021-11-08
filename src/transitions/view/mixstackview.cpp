/*
    SPDX-FileCopyrightText: 2017 Nicolas Carion
    SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "mixstackview.hpp"
#include "assets/keyframes/model/keyframemodellist.hpp"
#include "assets/model/assetparametermodel.hpp"
#include "core.h"
#include "monitor/monitor.h"
#include "timecodedisplay.h"

#include <QComboBox>
#include <QSignalBlocker>
#include <QDebug>
#include <QHBoxLayout>
#include <QToolButton>
#include <QLabel>
#include <klocalizedstring.h>

MixStackView::MixStackView(QWidget *parent)
    : AssetParameterView(parent)
{
    m_durationLayout = new QHBoxLayout;
    m_duration = new TimecodeDisplay(pCore->timecode(), this);
    m_duration->setRange(1, -1);
    m_durationLayout->addWidget(new QLabel(i18n("Duration:")));
    m_durationLayout->addWidget(m_duration);
    m_alignLeft = new QToolButton(this);
    m_alignLeft->setIcon(QIcon::fromTheme(QStringLiteral("align-horizontal-left")));
    m_alignLeft->setToolTip(i18n("Align left"));
    m_alignLeft->setAutoRaise(true);
    m_alignLeft->setCheckable(true);
    connect(m_alignLeft, &QToolButton::clicked, this, &MixStackView::slotAlignLeft);
    m_alignRight = new QToolButton(this);
    m_alignRight->setIcon(QIcon::fromTheme(QStringLiteral("align-horizontal-right")));
    m_alignRight->setToolTip(i18n("Align right"));
    m_alignRight->setAutoRaise(true);
    m_alignRight->setCheckable(true);
    connect(m_alignRight, &QToolButton::clicked, this, &MixStackView::slotAlignRight);
    m_alignCenter = new QToolButton(this);
    m_alignCenter->setIcon(QIcon::fromTheme(QStringLiteral("align-horizontal-center")));
    m_alignCenter->setToolTip(i18n("Center"));
    m_alignCenter->setAutoRaise(true);
    m_alignCenter->setCheckable(true);
    connect(m_alignCenter, &QToolButton::clicked, this, &MixStackView::slotAlignCenter);
    m_durationLayout->addStretch();
    m_durationLayout->addWidget(m_alignRight);
    m_durationLayout->addWidget(m_alignCenter);
    m_durationLayout->addWidget(m_alignLeft);
    connect(m_duration, &TimecodeDisplay::timeCodeUpdated, this, &MixStackView::updateDuration);
    connect(this, &AssetParameterView::seekToPos, [this](int pos) {
        // at this point, the effects returns a pos relative to the clip. We need to convert it to a global time
        int clipIn = pCore->getItemPosition(m_model->getOwnerId());
        emit seekToTransPos(pos + clipIn);
    });
}

void MixStackView::setModel(const std::shared_ptr<AssetParameterModel> &model, QSize frameSize, bool addSpacer)
{
    AssetParameterView::setModel(model, frameSize, addSpacer);
    m_model->setActive(true);
    auto kfr = model->getKeyframeModel();
    if (kfr) {
        connect(kfr.get(), &KeyframeModelList::modelChanged, this, &AssetParameterView::slotRefresh);
    }
    emit initKeyframeView(true);
    pCore->getMonitor(m_model->monitorId)->slotShowEffectScene(needsMonitorEffectScene());

    if (m_model->rowCount() > 0) {
        QSignalBlocker bk0(m_duration);
        m_duration->setValue(m_model->data(m_model->index(0, 0), AssetParameterModel::ParentDurationRole).toInt() + 1);
        connect(m_model.get(), &AssetParameterModel::dataChanged, this, &MixStackView::durationChanged);
    }
    checkAlignment();
    m_model->data(m_model->index(0, 0), AssetParameterModel::ParentDurationRole).toInt();
    m_lay->addLayout(m_durationLayout);
    m_lay->addStretch(10);
    slotRefresh();
}

void MixStackView::checkAlignment()
{
    int mainClipId = stackOwner().second;
    MixAlignment align = pCore->getMixAlign(mainClipId);
    QSignalBlocker bk1(m_alignLeft);
    QSignalBlocker bk2(m_alignRight);
    QSignalBlocker bk3(m_alignCenter);
    m_alignLeft->setChecked(false);
    m_alignRight->setChecked(false);
    m_alignCenter->setChecked(false);
    switch (align) {
        case MixAlignment::AlignLeft:
            m_alignLeft->setChecked(true);
            break;
        case MixAlignment::AlignRight:
            m_alignRight->setChecked(true);
            break;
        case MixAlignment::AlignCenter:
            m_alignCenter->setChecked(true);
            break;
        default:
            // No alignment
            break;
    }

}

void MixStackView::durationChanged(const QModelIndex &, const QModelIndex &, const QVector<int> &roles)
{
    if (roles.contains(AssetParameterModel::ParentDurationRole)) {
        QSignalBlocker bk1(m_duration);
        m_duration->setValue(m_model->data(m_model->index(0, 0), AssetParameterModel::ParentDurationRole).toInt() + 1);
        checkAlignment();
    }
}

MixAlignment MixStackView::alignment() const
{
    if (m_alignRight->isChecked()) {
        return MixAlignment::AlignRight;
    }
    if (m_alignLeft->isChecked()) {
        return MixAlignment::AlignLeft;
    }
    if (m_alignCenter->isChecked()) {
        return MixAlignment::AlignCenter;
    }
    return MixAlignment::AlignNone;
}

void MixStackView::updateDuration()
{
    pCore->resizeMix(stackOwner().second, m_duration->getValue() - 1, alignment());
}

void MixStackView::slotAlignLeft()
{
    if (!m_alignLeft->isChecked()) {
        return;
    }
    m_alignRight->setChecked(false);
    m_alignCenter->setChecked(false);
    pCore->resizeMix(stackOwner().second, m_duration->getValue() - 1, MixAlignment::AlignLeft);
}

void MixStackView::slotAlignRight()
{
    if (!m_alignRight->isChecked()) {
        return;
    }
    m_alignLeft->setChecked(false);
    m_alignCenter->setChecked(false);
    pCore->resizeMix(stackOwner().second, m_duration->getValue() - 1, MixAlignment::AlignRight);
}

void MixStackView::slotAlignCenter()
{
    if (!m_alignCenter->isChecked()) {
        return;
    }
    m_alignLeft->setChecked(false);
    m_alignRight->setChecked(false);
    pCore->resizeMix(stackOwner().second, m_duration->getValue() - 1, MixAlignment::AlignCenter);
}

void MixStackView::unsetModel()
{
    if (m_model) {
        m_model->setActive(false);
        m_lay->removeItem(m_durationLayout);
        auto kfr = m_model->getKeyframeModel();
        if (kfr) {
            disconnect(kfr.get(), &KeyframeModelList::modelChanged, this, &AssetParameterView::slotRefresh);
        }
        disconnect(m_model.get(), &AssetParameterModel::dataChanged, this, &MixStackView::durationChanged);
        pCore->getMonitor(m_model->monitorId)->slotShowEffectScene(MonitorSceneDefault);
    }
    AssetParameterView::unsetModel();
}

ObjectId MixStackView::stackOwner() const
{
    if (m_model) {
        return m_model->getOwnerId();
    }
    return ObjectId(ObjectType::NoItem, -1);
}
