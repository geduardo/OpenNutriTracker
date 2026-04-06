package com.opennutritracker.ont.opennutritracker

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "opennutritracker/health_connect"
    private val providerPackageName = "com.google.android.apps.healthdata"

    private lateinit var permissionsLauncher: ActivityResultLauncher<Set<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingRequestedPermissions: Set<String> = emptySet()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        permissionsLauncher =
            registerForActivityResult(
                PermissionController.createRequestPermissionResultContract(),
            ) { grantedPermissions: Set<String> ->
                val requestedPermissions = pendingRequestedPermissions
                pendingRequestedPermissions = emptySet()
                pendingPermissionResult?.success(
                    buildStatusMap(
                        permissionsGranted =
                            grantedPermissions.containsAll(requestedPermissions),
                        grantedPermissions = grantedPermissions,
                    ),
                )
                pendingPermissionResult = null
            }

        MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                channelName,
            )
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> getStatus(result)
                    "requestPermissions" -> requestPermissions(result)
                    "readWeights" -> readWeights(call, result)
                    "openHealthConnectSettings" -> openHealthConnectSettings(result)
                    "openHealthConnectManageData" -> openHealthConnectManageData(result)
                    "openHealthConnectStore" -> openHealthConnectStore(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun getStatus(result: MethodChannel.Result) {
        val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(buildStatusMap(permissionsGranted = false))
            return
        }

        lifecycleScope.launch {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val grantedPermissions = client.permissionController.getGrantedPermissions()
            val requestedPermissions = requestedPermissions(client)
            result.success(
                buildStatusMap(
                    permissionsGranted = grantedPermissions.containsAll(requestedPermissions),
                    grantedPermissions = grantedPermissions,
                ),
            )
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error(
                "health_connect_busy",
                "Another Health Connect permission request is already running.",
                null,
            )
            return
        }

        val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(buildStatusMap(permissionsGranted = false))
            return
        }

        lifecycleScope.launch {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            pendingPermissionResult = result
            pendingRequestedPermissions = requestedPermissions(client)
            permissionsLauncher.launch(pendingRequestedPermissions)
        }
    }

    private fun readWeights(call: MethodCall, result: MethodChannel.Result) {
        val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.error(
                "health_connect_unavailable",
                "Health Connect is not available on this device.",
                null,
            )
            return
        }

        lifecycleScope.launch {
            val client = HealthConnectClient.getOrCreate(this@MainActivity)
            val requestedPermissions = requestedPermissions(client)
            val grantedPermissions = client.permissionController.getGrantedPermissions()
            if (!grantedPermissions.containsAll(requestedPermissions)) {
                result.error(
                    "health_connect_permissions_missing",
                    "Health Connect permissions were not granted.",
                    null,
                )
                return@launch
            }

            val daysBack = call.argument<Int>("daysBack") ?: 3650
            val endTime = Instant.now()
            val startTime = endTime.minusSeconds(daysBack.toLong() * 24L * 60L * 60L)
            val weights = mutableListOf<Map<String, Any?>>()
            var pageToken: String? = null

            do {
                val response =
                    client.readRecords(
                        ReadRecordsRequest(
                            recordType = WeightRecord::class,
                            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                            pageSize = 1000,
                            pageToken = pageToken,
                        ),
                    )

                response.records.forEach { record ->
                    weights.add(
                        mapOf(
                            "timeMillis" to record.time.toEpochMilli(),
                            "weightKg" to record.weight.inKilograms,
                            "sourcePackageName" to record.metadata.dataOrigin.packageName,
                        ),
                    )
                }
                pageToken = response.pageToken
            } while (pageToken != null)

            result.success(weights)
        }
    }

    private fun openHealthConnectSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS))
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun openHealthConnectManageData(result: MethodChannel.Result) {
        val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
        if (sdkStatus != HealthConnectClient.SDK_AVAILABLE) {
            result.success(false)
            return
        }

        try {
            startActivity(
                HealthConnectClient.getHealthConnectManageDataIntent(
                    this,
                    providerPackageName,
                ),
            )
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun openHealthConnectStore(result: MethodChannel.Result) {
        val marketIntent =
            Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse(
                        "market://details?id=$providerPackageName&url=healthconnect%3A%2F%2Fonboarding",
                    ),
                )
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        val webIntent =
            Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse(
                        "https://play.google.com/store/apps/details?id=$providerPackageName",
                    ),
                )
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            startActivity(marketIntent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            try {
                startActivity(webIntent)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            }
        }
    }

    private fun requestedPermissions(client: HealthConnectClient): Set<String> {
        val permissions = mutableSetOf(HealthPermission.getReadPermission(WeightRecord::class))

        if (
            client.features.getFeatureStatus(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY) ==
                HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        ) {
            permissions.add(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY)
        }

        return permissions
    }

    private fun buildStatusMap(
        permissionsGranted: Boolean,
        grantedPermissions: Set<String> = emptySet(),
    ): Map<String, Any> {
        val sdkStatus = HealthConnectClient.getSdkStatus(this, providerPackageName)
        val historyPermissionGranted =
            grantedPermissions.contains(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY)

        return mapOf(
            "sdkStatus" to sdkStatus,
            "available" to (sdkStatus == HealthConnectClient.SDK_AVAILABLE),
            "updateRequired" to
                (sdkStatus == HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED),
            "providerPackageName" to providerPackageName,
            "permissionsGranted" to permissionsGranted,
            "historyPermissionGranted" to historyPermissionGranted,
        )
    }
}
