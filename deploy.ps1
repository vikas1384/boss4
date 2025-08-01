# Deployment script for Arogya AI
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$GITHUB_TOKEN,
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "production",
    
    [Parameter(Mandatory=$false)]
    [string]$Repository = "boss4",
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = "vikas1384"
)

# Function to validate token and repository access
function Test-GitHubToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Token,
        
        [Parameter(Mandatory=$false)]
        [string]$Repository = "boss4",
        
        [Parameter(Mandatory=$false)]
        [string]$Owner = "vikas1384"
    )
    
    try {
        $headers = @{
            'Authorization' = "Bearer $Token"
            'Accept' = 'application/vnd.github.v3+json'
        }
        
        # First validate token
        $userResponse = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers
        Write-Host "GitHub token validated successfully for user: $($userResponse.login)"
        
        # Then check repository access
        $repoUrl = "https://api.github.com/repos/$Owner/$Repository"
        $repoResponse = Invoke-RestMethod -Uri $repoUrl -Headers $headers
        Write-Host "Repository access confirmed: $($repoResponse.full_name)"
        
        # Check write access
        $permsUrl = "https://api.github.com/repos/$Owner/$Repository/collaborators/$($userResponse.login)/permission"
        $permsResponse = Invoke-RestMethod -Uri $permsUrl -Headers $headers
        
        if ($permsResponse.permission -in @('admin', 'write')) {
            Write-Host "Write access confirmed for repository"
            return $true
        } else {
            throw "User does not have write access to the repository"
        }
    }
    catch {
        Write-Error "Failed to validate GitHub token or repository access: $_"
        return $false
    }
}

# Function to start application deployment
function Start-ApplicationDeployment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Token,
        
        [Parameter(Mandatory=$false)]
        [string]$Branch = "production",
        
        [Parameter(Mandatory=$false)]
        [string]$Repository = "boss4",
        
        [Parameter(Mandatory=$false)]
        [string]$Owner = "vikas1384"
    )
    
    try {
        # Set error action preference
        $ErrorActionPreference = 'Stop'
        
        # Validate environment
        if (-not (Test-Path .env.production)) {
            throw "Production environment file not found"
        }

        # Install dependencies with retry logic
        Write-Host "Installing dependencies..."
        $retryCount = 0
        $maxRetries = 3
        
        do {
            try {
                npm ci --omit=dev --no-audit
                break
            } catch {
                $retryCount++
                if ($retryCount -eq $maxRetries) {
                    throw "Failed to install dependencies after $maxRetries attempts"
                }
                Write-Warning "Retry $retryCount of $maxRetries: Installing dependencies..."
                Start-Sleep -Seconds 5
            }
        } while ($retryCount -lt $maxRetries)

        # Create and clean build directory
        Write-Host "Preparing build directory..."
        if (Test-Path "dist") {
            Remove-Item "dist" -Recurse -Force
        }
        New-Item -ItemType Directory -Path "dist" | Out-Null

        # Run build with environment variables
        Write-Host "Building application..."
        $env:NODE_ENV = "production"
        npm run build

        # Use the GitHub token for deployment
        if (Test-GitHubToken -Token $Token) {
            Write-Host "Creating and switching to production branch..."
            try {
                git checkout production 2>$null
            } catch {
                git checkout -b production
            }
            
            # Set up git configuration
            git config --global user.name "GitHub Actions"
            git config --global user.email "actions@github.com"
            
            # Ensure all built files are tracked
            Get-ChildItem -Path "dist" -Recurse | ForEach-Object {
                git add $_.FullName -f
            }
            
            # Add other necessary files
            git add .env.production -f
            git add server.js -f
            git add package.json package-lock.json -f
            
            # Commit changes
            git commit -m "Deploy: Production build $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            
            # Push to deployment branch using the token
            $repoUrl = "https://${Token}@github.com/vikas1384/boss4.git"
            Write-Host "Pushing to production branch..."
            
            # Ensure the remote is set up correctly
            git remote remove origin 2>$null
            git remote add origin $repoUrl
            
            # Force push to production branch
            git push -u origin HEAD:production -f
            
            Write-Host "Deployment completed successfully"
            git checkout main # Switch back to main branch
            return $true
        }
        else {
            throw "GitHub token validation failed"
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        return $false
    }
}

# Main execution
Write-Host "Starting deployment process..."
if (Start-ApplicationDeployment -Token $GITHUB_TOKEN) {
    Write-Host "Deployment completed successfully"
    exit 0
} else {
    Write-Error "Deployment failed"
    exit 1
}
