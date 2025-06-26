import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Upload, Activity, AlertTriangle, XCircle, 
  TrendingUp, Clock, CheckCircle, FileText
} from 'lucide-react';

interface DashboardStats {
  totalUploads: number;
  pendingJobs: number;
  piiFound: number;
  falsePendingReview: number;
}

interface UploadData {
  date: string;
  uploads: number;
}

interface Alert {
  id: string;
  type: 'warning' | 'error' | 'info';
  message: string;
  timestamp: string;
}

export const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats>({
    totalUploads: 0,
    pendingJobs: 0,
    piiFound: 0,
    falsePendingReview: 0
  });
  const [uploadChartData, setUploadChartData] = useState<UploadData[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        // Buscar status da fila
        const queueResponse = await fetch('/api/queue/status');
        const queueData = await queueResponse.json();

        // Buscar estatísticas reais do backend
        const statsResponse = await fetch('/api/v1/statistics');
        const statsData = await statsResponse.json();

        setStats({
          totalUploads: statsData.totalFiles || 0,
          pendingJobs: queueData.queues?.archive?.waiting || 0,
          piiFound: statsData.totalDetections || 0,
          falsePendingReview: statsData.falsePendingReview || 0
        });

        // Buscar dados do gráfico de uploads (exemplo)
        setUploadChartData(statsData.uploadsByDay || []);

        // Buscar alertas reais, se existir endpoint
        setAlerts(statsData.alerts || []);

        setLoading(false);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        setStats({
          totalUploads: 0,
          pendingJobs: 0,
          piiFound: 0,
          falsePendingReview: 0
        });
        setUploadChartData([]);
        setAlerts([]);
        setLoading(false);
      }
    };

    fetchDashboardData();
    const interval = setInterval(fetchDashboardData, 30000);
    return () => clearInterval(interval);
  }, []);

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit'
    });
  };

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString('pt-BR');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6 fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-h1" style={{ color: 'var(--color-text-primary)' }}>
          Dashboard - n<span style={{ color: 'var(--color-primary)' }}>.</span>crisis
        </h1>
        <Link
          to="/files/upload"
          className="btn btn-primary"
        >
          <Upload size={16} />
          Novo upload
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Link
          to="/files/my-uploads"
          className="card-metric text-decoration-none"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-small" style={{ color: 'var(--color-text-secondary)', marginBottom: '0.5rem' }}>
                Total de uploads
              </p>
              <p className="text-h1" style={{ color: 'var(--color-text-primary)' }}>
                {stats.totalUploads.toLocaleString()}
              </p>
            </div>
            <FileText className="h-12 w-12" style={{ color: 'var(--color-primary)' }} />
          </div>
        </Link>

        <Link
          to="/jobs/queue"
          className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow border border-gray-200 dark:border-gray-700"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                Jobs pendentes
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white">
                {stats.pendingJobs}
              </p>
            </div>
            <Activity className="h-12 w-12 text-orange-500" />
          </div>
        </Link>

        <Link
          to="/detections"
          className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow border border-gray-200 dark:border-gray-700"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                PII encontradas
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white">
                {stats.piiFound.toLocaleString()}
              </p>
            </div>
            <AlertTriangle className="h-12 w-12 text-red-500" />
          </div>
        </Link>

        <Link
          to="/detections?filter=false-positive"
          className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md hover:shadow-lg transition-shadow border border-gray-200 dark:border-gray-700"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
                Falsos-positivos pendentes
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white">
                {stats.falsePendingReview}
              </p>
            </div>
            <XCircle className="h-12 w-12 text-yellow-500" />
          </div>
        </Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Upload Chart */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md border border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            Uploads por dia (últimos 7 dias)
          </h3>
          <div className="h-64 flex items-end space-x-2">
            {uploadChartData.map((data, index) => {
              const maxUploads = Math.max(...uploadChartData.map(d => d.uploads));
              const height = (data.uploads / maxUploads) * 100;
              
              return (
                <div key={index} className="flex-1 flex flex-col items-center">
                  <div
                    className="bg-blue-500 rounded-t-sm w-full transition-all duration-300 hover:bg-blue-600"
                    style={{ height: `${height}%` }}
                    title={`${data.uploads} uploads`}
                  ></div>
                  <span className="text-xs text-gray-600 dark:text-gray-400 mt-2">
                    {formatDate(data.date)}
                  </span>
                  <span className="text-xs font-medium text-gray-900 dark:text-white">
                    {data.uploads}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Recent Alerts */}
        <div className="bg-white dark:bg-gray-800 p-6 rounded-lg shadow-md border border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            Últimos alertas
          </h3>
          <div className="space-y-3">
            {alerts.length === 0 ? (
              <div className="flex items-center gap-2 text-green-600">
                <CheckCircle size={16} />
                <span className="text-sm">Nenhum alerta recente</span>
              </div>
            ) : (
              alerts.map((alert) => (
                <div
                  key={alert.id}
                  className={`p-3 rounded-lg border-l-4 ${
                    alert.type === 'error'
                      ? 'bg-red-50 border-red-500 dark:bg-red-900/20'
                      : alert.type === 'warning'
                      ? 'bg-yellow-50 border-yellow-500 dark:bg-yellow-900/20'
                      : 'bg-blue-50 border-blue-500 dark:bg-blue-900/20'
                  }`}
                >
                  <div className="flex items-start gap-2">
                    {alert.type === 'error' ? (
                      <XCircle size={16} className="text-red-500 mt-0.5" />
                    ) : alert.type === 'warning' ? (
                      <AlertTriangle size={16} className="text-yellow-500 mt-0.5" />
                    ) : (
                      <Clock size={16} className="text-blue-500 mt-0.5" />
                    )}
                    <div className="flex-1">
                      <p className="text-sm font-medium text-gray-900 dark:text-white">
                        {alert.message}
                      </p>
                      <p className="text-xs text-gray-600 dark:text-gray-400 mt-1">
                        {formatTimestamp(alert.timestamp)}
                      </p>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};