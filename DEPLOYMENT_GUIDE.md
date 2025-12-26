# 🚀 Deployment Guide for PDF Search App

## Prerequisites
✅ Flutter web app working locally
✅ Git repository initialized
✅ Backend deployed on Heroku

---

## 📦 Build the App First

```bash
flutter build web --release
```

This creates optimized files in `build/web/`

---

## 🔥 Option 1: Deploy to Firebase Hosting

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Firebase (if not already done)
```bash
firebase init hosting
```
Select:
- Use an existing project or create new one
- Public directory: `build/web`
- Single-page app: **Yes**
- Set up automatic builds: **No** (we build locally)

### Step 4: Deploy
```bash
flutter build web --release
firebase deploy --only hosting
```

Your app will be live at: `https://YOUR-PROJECT.web.app`

### Quick Redeploy
```bash
flutter build web --release && firebase deploy --only hosting
```

---

## 🌐 Option 2: Deploy to Netlify

### Method A: Netlify CLI (Recommended)

#### Step 1: Install Netlify CLI
```bash
npm install -g netlify-cli
```

#### Step 2: Login to Netlify
```bash
netlify login
```

#### Step 3: Deploy
```bash
# First time (creates new site)
flutter build web --release
netlify deploy --prod

# Choose:
# - Create & configure a new site: Yes
# - Publish directory: build/web
```

Your app will be live at: `https://YOUR-SITE-NAME.netlify.app`

#### Quick Redeploy
```bash
flutter build web --release && netlify deploy --prod
```

### Method B: Netlify Web UI (Drag & Drop)

1. Build your app: `flutter build web --release`
2. Go to https://app.netlify.com/drop
3. Drag the `build/web` folder to the drop zone
4. Done! Your site is live

### Method C: Git-based Deployment

1. Push code to GitHub:
```bash
git add .
git commit -m "Ready for deployment"
git push origin main
```

2. Go to https://app.netlify.com
3. Click "Add new site" → "Import an existing project"
4. Connect your GitHub repository
5. Build settings:
   - **Build command:** `flutter build web --release`
   - **Publish directory:** `build/web`
6. Click "Deploy site"

Netlify will auto-deploy on every git push!

---

## 🔧 Troubleshooting

### Issue: "CORS error" when calling API
**Fix:** Backend must allow CORS from your domain

Add to your Heroku backend:
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://YOUR-SITE.web.app",      # Firebase
        "https://YOUR-SITE.netlify.app",  # Netlify
        "http://localhost:*",              # Local dev
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Issue: "Blank page" after deployment
1. Check browser console for errors (F12)
2. Verify API endpoint in `api_service.dart` is correct
3. Clear browser cache (Ctrl+Shift+Delete)

### Issue: "File picker not working"
✅ Already fixed! Your code handles web with `withData: kIsWeb`

---

## 🎯 Recommended Workflow

1. **Development:** Test locally with `flutter run -d chrome`
2. **Build:** `flutter build web --release`
3. **Deploy:** 
   - Firebase: `firebase deploy --only hosting`
   - Netlify: `netlify deploy --prod`

---

## 📝 Custom Domain (Optional)

### Firebase:
1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow DNS setup instructions

### Netlify:
1. Go to Site settings → Domain management
2. Click "Add custom domain"
3. Update DNS records with your domain provider

---

## ✅ Verification Checklist

After deployment, test:
- ✅ App loads without errors
- ✅ Can navigate between screens (Process, Colors, Dims)
- ✅ Search functionality works
- ✅ Upload Excel works
- ✅ Data displays correctly in tables
- ✅ Refresh button works
- ✅ Mobile responsive (test on phone)

---

## 🚀 You're Live!

Share your app:
- **Firebase:** `https://YOUR-PROJECT.web.app`
- **Netlify:** `https://YOUR-SITE.netlify.app`

**Tip:** Use Netlify for easier setup and auto-deploy from Git!
