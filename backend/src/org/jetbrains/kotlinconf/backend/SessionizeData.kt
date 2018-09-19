package org.jetbrains.kotlinconf.backend

import kotlinx.serialization.*

@Serializable
data class ConfSession(
    val id: String,
    val startsAt: String,
    val endsAt: String,
    val roomId: Int
)

@Serializable
data class ConfRoom(
    val sessions: List<ConfSession>
)


@Serializable
data class ConfSchedule(
    val rooms: List<ConfRoom>
)