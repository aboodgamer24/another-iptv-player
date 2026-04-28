package dev.ogos.anotheriptvplayer

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*

// --- Theme Tokens ---
private val DeepSpaceDark = Color(0xFF080810)
private val ElectricBlue = Color(0xFF4F8EF7)
private val SoftPurple = Color(0xFF7B61FF)
private val TextSecondary = Color(0xFF9A9AA8)
private val TextMuted = Color(0xFF555568)
private val BorderDark = Color(0xFF2A2A3E)
private val SurfaceDark = Color(0xFF12121E)
private val SurfaceFocused = Color(0xFF1A1A2E)

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvWelcomeScreen(onDone: () -> Unit) {
    val vm: TvWelcomeViewModel = viewModel()
    val step by vm.currentStep.collectAsState()
    val errorMessage by vm.errorMessage.collectAsState()
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DeepSpaceDark)
            .drawBehind {
                drawRect(
                    Brush.radialGradient(
                        colors = listOf(
                            ElectricBlue.copy(alpha = 0.08f),
                            Color.Transparent
                        ),
                        center = center,
                        radius = size.maxDimension / 1.5f
                    )
                )
            }
    ) {
        when (step) {
            is WelcomeStep.Welcome -> WelcomeStepScreen(vm)
            is WelcomeStep.LoginForm -> LoginFormScreen(vm, context)
            is WelcomeStep.RegisterForm -> RegisterFormScreen(vm, context)
            is WelcomeStep.Syncing -> SyncingScreen()
            is WelcomeStep.NeedsPlaylist -> NeedsPlaylistScreen(vm, onDone)
            is WelcomeStep.Error -> ErrorScreen(vm, errorMessage)
            is WelcomeStep.Done -> {
                LaunchedEffect(Unit) {
                    onDone()
                }
            }
        }
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun WelcomeStepScreen(vm: TvWelcomeViewModel) {
    val loginFocus = remember { FocusRequester() }
    
    LaunchedEffect(Unit) {
        loginFocus.requestFocus()
    }

    Row(modifier = Modifier.fillMaxSize()) {
        // Left Panel
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(horizontal = 80.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.Start
        ) {
            StaggeredItem(index = 0) {
                Icon(
                    imageVector = Icons.Default.PlayCircle,
                    contentDescription = null,
                    modifier = Modifier.size(56.dp),
                    tint = ElectricBlue
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            StaggeredItem(index = 1) {
                Text(
                    text = "C4-TV",
                    style = MaterialTheme.typography.displayLarge.copy(
                        fontSize = 72.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = (-2).sp
                    ),
                    color = Color.White
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            StaggeredItem(index = 2) {
                Text(
                    text = "Your entertainment. Anywhere.",
                    style = MaterialTheme.typography.headlineSmall.copy(
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Light
                    ),
                    color = TextSecondary
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            StaggeredItem(index = 3) {
                Text(
                    text = "Version 1.0",
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                    color = Color(0xFF33334A)
                )
            }
            Spacer(modifier = Modifier.height(48.dp))
        }

        // Vertical Divider
        Box(
            modifier = Modifier
                .width(1.dp)
                .fillMaxHeight()
                .background(Color(0xFF1E1E30))
        )

        // Right Panel
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            StaggeredItem(index = 0) {
                Text(
                    text = "GET STARTED",
                    color = TextMuted,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 1.5.sp
                )
            }
            Spacer(modifier = Modifier.height(32.dp))
            
            StaggeredItem(index = 1) {
                PrimaryButton(
                    text = "Login",
                    onClick = { vm.setStep(WelcomeStep.LoginForm) },
                    modifier = Modifier.focusRequester(loginFocus)
                )
            }
            Spacer(modifier = Modifier.height(14.dp))
            
            StaggeredItem(index = 2) {
                OutlinedSecondaryButton(
                    text = "Register",
                    onClick = { vm.setStep(WelcomeStep.RegisterForm) }
                )
            }
            Spacer(modifier = Modifier.height(14.dp))
            
            StaggeredItem(index = 3) {
                GhostButton(
                    text = "Continue as Guest",
                    subtitle = "Add a playlist manually",
                    onClick = {
                        vm.isGuestMode = true
                        vm.setStep(WelcomeStep.Done)
                    }
                )
            }
        }
    }
}

@Composable
fun LoginFormScreen(vm: TvWelcomeViewModel, context: android.content.Context) {
    var serverUrl by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(modifier = Modifier.width(400.dp)) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { vm.setStep(WelcomeStep.Welcome) },
                    tint = TextSecondary
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Sign In",
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Color.White
                )
            }
            Text(
                text = "Restore your playlists and settings",
                color = TextMuted,
                fontSize = 14.sp,
                modifier = Modifier.padding(start = 32.dp)
            )
            
            Spacer(modifier = Modifier.height(32.dp))

            CustomTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = "Server URL",
                placeholder = "https://sync.example.com",
                keyboardType = KeyboardType.Uri,
                imeAction = ImeAction.Next,
                modifier = Modifier.focusRequester(focusRequester)
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email",
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = password,
                onValueChange = { password = it },
                label = "Password",
                isPassword = true,
                imeAction = ImeAction.Done
            )
            
            Spacer(modifier = Modifier.height(28.dp))

            PrimaryButton(
                text = "Sign In",
                onClick = { vm.signIn(context, serverUrl, email, password) },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedSecondaryButton(
                text = "Back",
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier.fillMaxWidth()
            )

            val error = vm.errorMessage.collectAsState().value
            if (error != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = error,
                    color = androidx.compose.material3.MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 2
                )
            }
        }
    }
}

@Composable
fun RegisterFormScreen(vm: TvWelcomeViewModel, context: android.content.Context) {
    var serverUrl by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(null) }
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(modifier = Modifier.width(400.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { vm.setStep(WelcomeStep.Welcome) },
                    tint = TextSecondary
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Create Account",
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Color.White
                )
            }
            Text(
                text = "Free sync across all your devices",
                color = TextMuted,
                fontSize = 14.sp,
                modifier = Modifier.padding(start = 32.dp)
            )
            
            Spacer(modifier = Modifier.height(32.dp))

            CustomTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = "Server URL",
                placeholder = "https://sync.example.com",
                keyboardType = KeyboardType.Uri,
                imeAction = ImeAction.Next,
                modifier = Modifier.focusRequester(focusRequester)
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = name,
                onValueChange = { name = it },
                label = "Full Name",
                imeAction = ImeAction.Next
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email",
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = password,
                onValueChange = { password = it; localError = null },
                label = "Password",
                isPassword = true,
                imeAction = ImeAction.Next
            )
            Spacer(modifier = Modifier.height(16.dp))
            CustomTextField(
                value = confirmPassword,
                onValueChange = { confirmPassword = it; localError = null },
                label = "Confirm Password",
                isPassword = true,
                imeAction = ImeAction.Done
            )
            
            val error = localError ?: vm.errorMessage.collectAsState().value
            if (error != null) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = error,
                    color = androidx.compose.material3.MaterialTheme.colorScheme.error,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Spacer(modifier = Modifier.height(28.dp))

            PrimaryButton(
                text = "Create Account",
                onClick = { 
                    if (password != confirmPassword) {
                        localError = "Passwords do not match"
                    } else {
                        vm.register(context, serverUrl, name, email, password)
                    }
                },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedSecondaryButton(
                text = "Back",
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun SyncingScreen() {
    val vm: TvWelcomeViewModel = viewModel()
    val alphaPulse = rememberInfiniteTransition()
    val alpha by alphaPulse.animateFloat(
        initialValue = 0.6f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(tween(1000), RepeatMode.Reverse),
        label = "alpha"
    )
    
    val ringPulse = rememberInfiniteTransition()
    val outerRadius by ringPulse.animateFloat(
        initialValue = 78f,
        targetValue = 88f,
        animationSpec = infiniteRepeatable(tween(1200), RepeatMode.Reverse),
        label = "radius"
    )

    val rotation = rememberInfiniteTransition()
    val rotateAngle by rotation.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(2000, easing = LinearEasing)),
        label = "rotation"
    )

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(contentAlignment = Alignment.Center) {
            Canvas(modifier = Modifier.size(200.dp)) {
                drawCircle(
                    color = ElectricBlue.copy(alpha = 0.15f),
                    radius = outerRadius.dp.toPx(),
                    style = Stroke(width = 2.dp.toPx())
                )
                drawCircle(
                    color = ElectricBlue.copy(alpha = 0.35f),
                    radius = 56.dp.toPx(),
                    style = Stroke(width = 2.dp.toPx())
                )
            }
            Icon(
                Icons.Default.Sync,
                contentDescription = null,
                modifier = Modifier
                    .size(36.dp)
                    .graphicsLayer { rotationZ = rotateAngle },
                tint = ElectricBlue
            )
        }
        Spacer(modifier = Modifier.height(32.dp))
        Text(
            text = "Connecting to your account…",
            fontSize = 18.sp,
            color = Color.White.copy(alpha = alpha)
        )
    }
}

@Composable
fun ErrorScreen(vm: TvWelcomeViewModel, errorMessage: String?) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            Icons.Default.ErrorOutline,
            contentDescription = null,
            modifier = Modifier.size(72.dp),
            tint = Color(0xFFFF4F6A)
        )
        Spacer(modifier = Modifier.height(20.dp))
        Text(
            text = "Something went wrong",
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = errorMessage ?: "An unknown error occurred",
            fontSize = 15.sp,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 420.dp),
            maxLines = 3
        )
        Spacer(modifier = Modifier.height(36.dp))
        PrimaryButton(
            text = "Try Again",
            onClick = { vm.setStep(WelcomeStep.Welcome) },
            modifier = Modifier.focusRequester(focusRequester)
        )
        Spacer(modifier = Modifier.height(12.dp))
        GhostButton(
            text = "Continue as Guest",
            onClick = {
                vm.isGuestMode = true
                vm.setStep(WelcomeStep.Done)
            }
        )
    }
}

@Composable
fun NeedsPlaylistScreen(vm: TvWelcomeViewModel, onDone: () -> Unit) {
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            modifier = Modifier.width(400.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Default.PlaylistAdd,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = ElectricBlue
            )
            Spacer(modifier = Modifier.height(20.dp))
            Text(
                text = "You're in!",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Add a playlist to start watching",
                fontSize = 16.sp,
                color = TextSecondary
            )
            Spacer(modifier = Modifier.height(36.dp))
            PrimaryButton(
                text = "Go to Settings",
                onClick = {
                    vm.pendingNavigationTab = 7
                    onDone()
                },
                modifier = Modifier.focusRequester(focusRequester).fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))
            GhostButton(
                text = "Skip for now",
                onClick = { onDone() },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

// --- Helper UI Components ---

@Composable
private fun StaggeredItem(index: Int, content: @Composable () -> Unit) {
    val visible = remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(index * 80L)
        visible.value = true
    }
    AnimatedVisibility(
        visible = visible.value,
        enter = fadeIn(tween(380, easing = FastOutSlowInEasing)) + 
                slideInVertically(tween(380, easing = FastOutSlowInEasing), initialOffsetY = { 40 })
    ) {
        content()
    }
}

@Composable
private fun FocusScaleButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.(Boolean) -> Unit
) {
    var focused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (focused) 1.04f else 1f,
        animationSpec = tween(180),
        label = "scale"
    )
    Box(
        modifier = modifier
            .graphicsLayer { 
                scaleX = scale
                scaleY = scale
            }
            .onFocusChanged { focused = it.isFocused }
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        content(focused)
    }
}

@Composable
private fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    FocusScaleButton(
        onClick = onClick,
        modifier = modifier
            .width(320.dp)
            .height(60.dp)
            .clip(RoundedCornerShape(14.dp))
    ) { isFocused ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    if (isFocused) Brush.horizontalGradient(listOf(Color.White, Color.White))
                    else Brush.horizontalGradient(listOf(ElectricBlue, SoftPurple))
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = text,
                color = if (isFocused) ElectricBlue else Color.White,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun OutlinedSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    FocusScaleButton(
        onClick = onClick,
        modifier = modifier
            .width(320.dp)
            .height(60.dp)
            .clip(RoundedCornerShape(14.dp))
            .border(
                width = 1.dp,
                color = ElectricBlue.copy(alpha = 0.5f),
                shape = RoundedCornerShape(14.dp)
            )
    ) { isFocused ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(if (isFocused) ElectricBlue.copy(alpha = 0.12f) else Color.Transparent)
                .drawBehind {
                    if (isFocused) {
                        drawRoundRect(
                            color = ElectricBlue,
                            cornerRadius = androidx.compose.ui.geometry.CornerRadius(14.dp.toPx()),
                            style = Stroke(width = 2.dp.toPx())
                        )
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = text,
                color = if (isFocused) Color.White else TextSecondary,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun GhostButton(
    text: String,
    subtitle: String? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var focused by remember { mutableStateOf(false) }
    Column(
        modifier = modifier
            .onFocusChanged { focused = it.isFocused }
            .clickable { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = text,
            color = if (focused) Color.White else Color(0xFF666680),
            fontSize = 17.sp,
            textDecoration = if (focused) TextDecoration.Underline else null
        )
        if (subtitle != null) {
            Text(
                text = subtitle,
                color = Color(0xFF44445A),
                fontSize = 12.sp
            )
        }
    }
}

@Composable
private fun CustomTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    placeholder: String = "",
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Default,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .height(64.dp),
        label = { Text(label, color = TextMuted) },
        placeholder = { Text(placeholder, color = TextMuted) },
        visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType, imeAction = imeAction),
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = ElectricBlue,
            unfocusedBorderColor = BorderDark,
            focusedContainerColor = SurfaceFocused,
            unfocusedContainerColor = SurfaceDark,
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White
        )
    )
}
