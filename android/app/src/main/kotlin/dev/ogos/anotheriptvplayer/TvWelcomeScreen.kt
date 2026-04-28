package dev.ogos.anotheriptvplayer

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Sync
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.tv.material3.*

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun TvWelcomeScreen(onDone: () -> Unit) {
    val vm: TvWelcomeViewModel = viewModel()
    val step by vm.currentStep.collectAsState()
    val context = LocalContext.current

    TvTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(TvColors.Background)
        ) {
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    fadeIn(tween(400)) togetherWith fadeOut(tween(400))
                },
                label = "step"
            ) { targetStep ->
                when (targetStep) {
                    is WelcomeStep.Welcome -> WelcomeStepContent(vm)
                    is WelcomeStep.LoginForm -> LoginFormContent(vm)
                    is WelcomeStep.RegisterForm -> RegisterFormContent(vm)
                    is WelcomeStep.Syncing -> SyncingContent()
                    is WelcomeStep.NeedsPlaylist -> NeedsPlaylistContent(vm, onDone)
                    is WelcomeStep.Error -> ErrorContent(vm, (targetStep as WelcomeStep.Error).message)
                    is WelcomeStep.Done -> {
                        LaunchedEffect(Unit) { onDone() }
                        Box(Modifier.fillMaxSize())
                    }
                }
            }
        }
    }
}

@Composable
fun WelcomeStepContent(vm: TvWelcomeViewModel) {
    val loginFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) { loginFocus.requestFocus() }

    Row(modifier = Modifier.fillMaxSize()) {
        // Left: Branding
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(80.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "ANOTHER",
                style = MaterialTheme.typography.labelSmall,
                color = TvColors.Primary
            )
            Text(
                text = "IPTV PLAYER",
                style = MaterialTheme.typography.displayLarge
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Sync your playlists, favorites, and watch history across all your devices seamlessly.",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.width(400.dp)
            )
        }

        // Right: Actions
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.3f))
                    )
                ),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            TvPrimaryButton(
                text = "Sign In",
                onClick = { vm.setStep(WelcomeStep.LoginForm) },
                modifier = Modifier.focusRequester(loginFocus).width(300.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvSecondaryButton(
                text = "Create Account",
                onClick = { vm.setStep(WelcomeStep.RegisterForm) },
                modifier = Modifier.width(300.dp)
            )
            Spacer(modifier = Modifier.height(32.dp))
            ClickableText(
                text = "Continue as Guest",
                onClick = {
                    vm.isGuestMode = true
                    vm.setStep(WelcomeStep.Done)
                },
                color = TvColors.TextMuted
            )
        }
    }
}

@Composable
fun LoginFormContent(vm: TvWelcomeViewModel) {
    var serverUrl by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val context = LocalContext.current
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.width(400.dp)) {
            Text("Sign In", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(32.dp))

            TvTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = "Sync Server URL",
                modifier = Modifier.focusRequester(focusRequester),
                keyboardType = KeyboardType.Uri
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email Address",
                keyboardType = KeyboardType.Email
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvTextField(
                value = password,
                onValueChange = { password = it },
                label = "Password",
                isPassword = true,
                imeAction = ImeAction.Done
            )
            
            Spacer(modifier = Modifier.height(32.dp))
            TvPrimaryButton(
                text = "Login & Sync",
                onClick = { vm.signIn(context, serverUrl, email, password) },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvSecondaryButton(
                text = "Cancel",
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun RegisterFormContent(vm: TvWelcomeViewModel) {
    var serverUrl by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val context = LocalContext.current
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.width(400.dp)) {
            Text("Create Account", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(32.dp))

            TvTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = "Sync Server URL",
                modifier = Modifier.focusRequester(focusRequester),
                keyboardType = KeyboardType.Uri
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvTextField(
                value = name,
                onValueChange = { name = it },
                label = "Display Name"
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvTextField(
                value = email,
                onValueChange = { email = it },
                label = "Email Address",
                keyboardType = KeyboardType.Email
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvTextField(
                value = password,
                onValueChange = { password = it },
                label = "Password",
                isPassword = true,
                imeAction = ImeAction.Done
            )
            
            Spacer(modifier = Modifier.height(32.dp))
            TvPrimaryButton(
                text = "Register",
                onClick = { vm.register(context, serverUrl, name, email, password) },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(16.dp))
            TvSecondaryButton(
                text = "Back",
                onClick = { vm.setStep(WelcomeStep.Welcome) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun SyncingContent() {
    val rotation = rememberInfiniteTransition().animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(2000, easing = LinearEasing))
    )

    Column(
        Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            Icons.Default.Sync,
            contentDescription = null,
            modifier = Modifier.size(64.dp).graphicsLayer { rotationZ = rotation.value },
            tint = TvColors.Primary
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text("Synchronizing data...", style = MaterialTheme.typography.titleLarge)
    }
}

@Composable
fun NeedsPlaylistContent(vm: TvWelcomeViewModel, onDone: () -> Unit) {
    var url by remember { mutableStateOf("") }
    var user by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    val context = LocalContext.current
    val focus = remember { FocusRequester() }

    LaunchedEffect(Unit) { focus.requestFocus() }

    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(Modifier.width(450.dp)) {
            Text("Add Xtream Playlist", style = MaterialTheme.typography.headlineMedium)
            Text("No playlists found. Please add one to continue.", color = TvColors.TextSecondary)
            Spacer(modifier = Modifier.height(32.dp))

            TvTextField(url, { url = it }, "Server URL (http://...)", Modifier.focusRequester(focus))
            Spacer(modifier = Modifier.height(12.dp))
            TvTextField(user, { user = it }, "Username")
            Spacer(modifier = Modifier.height(12.dp))
            TvTextField(pass, { pass = it }, "Password", isPassword = true, imeAction = ImeAction.Done)

            Spacer(modifier = Modifier.height(32.dp))
            TvPrimaryButton("Save Playlist", {
                if (url.isNotBlank() && user.isNotBlank()) {
                    TvRepository.savePlaylist(context, url, user, pass)
                    onDone()
                }
            }, Modifier.fillMaxWidth())
        }
    }
}

@Composable
fun ErrorContent(vm: TvWelcomeViewModel, message: String) {
    Column(
        Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Error", style = MaterialTheme.typography.headlineMedium, color = TvColors.Error)
        Spacer(modifier = Modifier.height(16.dp))
        Text(message, style = MaterialTheme.typography.bodyMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(modifier = Modifier.height(32.dp))
        TvPrimaryButton("Try Again", { vm.setStep(WelcomeStep.Welcome) })
    }
}

@Composable
fun ClickableText(text: String, onClick: () -> Unit, color: Color) {
    var isFocused by remember { mutableStateOf(false) }
    Text(
        text = text,
        modifier = Modifier
            .onFocusChanged { isFocused = it.isFocused }
            .clickable(onClick = onClick)
            .padding(8.dp),
        color = if (isFocused) Color.White else color,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = if (isFocused) FontWeight.Bold else FontWeight.Normal,
        textDecoration = if (isFocused) androidx.compose.ui.text.style.TextDecoration.Underline else null
    )
}
