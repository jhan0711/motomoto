export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: '14.5';
  };
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action: string;
          actor_id: string | null;
          after_data: Json | null;
          before_data: Json | null;
          created_at: string;
          entity_id: string | null;
          entity_type: string;
          id: number;
        };
        Insert: {
          action: string;
          actor_id?: string | null;
          after_data?: Json | null;
          before_data?: Json | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type: string;
          id?: never;
        };
        Update: {
          action?: string;
          actor_id?: string | null;
          after_data?: Json | null;
          before_data?: Json | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type?: string;
          id?: never;
        };
        Relationships: [
          {
            foreignKeyName: 'admin_audit_logs_actor_id_fkey';
            columns: ['actor_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      app_settings: {
        Row: {
          description: string;
          key: string;
          updated_at: string;
          updated_by: string | null;
          value: Json;
        };
        Insert: {
          description: string;
          key: string;
          updated_at?: string;
          updated_by?: string | null;
          value: Json;
        };
        Update: {
          description?: string;
          key?: string;
          updated_at?: string;
          updated_by?: string | null;
          value?: Json;
        };
        Relationships: [
          {
            foreignKeyName: 'app_settings_updated_by_fkey';
            columns: ['updated_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      document_types: {
        Row: {
          code: string;
          created_at: string;
          id: string;
          is_active: boolean;
          name: string;
          owner: Database['public']['Enums']['document_owner'];
          requires_expiry: boolean;
          sort_order: number;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          id?: string;
          is_active?: boolean;
          name: string;
          owner: Database['public']['Enums']['document_owner'];
          requires_expiry?: boolean;
          sort_order?: number;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          id?: string;
          is_active?: boolean;
          name?: string;
          owner?: Database['public']['Enums']['document_owner'];
          requires_expiry?: boolean;
          sort_order?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      documents: {
        Row: {
          created_at: string;
          document_type_id: string;
          driver_id: string | null;
          expires_at: string | null;
          file_path: string;
          id: string;
          issued_at: string | null;
          owner: Database['public']['Enums']['document_owner'];
          updated_at: string;
          uploaded_by: string | null;
          vehicle_id: string | null;
        };
        Insert: {
          created_at?: string;
          document_type_id: string;
          driver_id?: string | null;
          expires_at?: string | null;
          file_path: string;
          id?: string;
          issued_at?: string | null;
          owner: Database['public']['Enums']['document_owner'];
          updated_at?: string;
          uploaded_by?: string | null;
          vehicle_id?: string | null;
        };
        Update: {
          created_at?: string;
          document_type_id?: string;
          driver_id?: string | null;
          expires_at?: string | null;
          file_path?: string;
          id?: string;
          issued_at?: string | null;
          owner?: Database['public']['Enums']['document_owner'];
          updated_at?: string;
          uploaded_by?: string | null;
          vehicle_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'documents_driver_id_fkey';
            columns: ['driver_id'];
            isOneToOne: false;
            referencedRelation: 'drivers';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'documents_type_matches_owner';
            columns: ['document_type_id', 'owner'];
            isOneToOne: false;
            referencedRelation: 'document_types';
            referencedColumns: ['id', 'owner'];
          },
          {
            foreignKeyName: 'documents_uploaded_by_fkey';
            columns: ['uploaded_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'documents_vehicle_id_fkey';
            columns: ['vehicle_id'];
            isOneToOne: false;
            referencedRelation: 'vehicles';
            referencedColumns: ['id'];
          },
        ];
      };
      driver_locations: {
        Row: {
          accuracy_m: number | null;
          driver_id: string;
          heading: number | null;
          location: unknown;
          speed_kmh: number | null;
          updated_at: string;
        };
        Insert: {
          accuracy_m?: number | null;
          driver_id: string;
          heading?: number | null;
          location: unknown;
          speed_kmh?: number | null;
          updated_at?: string;
        };
        Update: {
          accuracy_m?: number | null;
          driver_id?: string;
          heading?: number | null;
          location?: unknown;
          speed_kmh?: number | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'driver_locations_driver_id_fkey';
            columns: ['driver_id'];
            isOneToOne: true;
            referencedRelation: 'drivers';
            referencedColumns: ['id'];
          },
        ];
      };
      driver_vehicle_assignments: {
        Row: {
          assigned_at: string;
          assigned_by: string | null;
          driver_id: string;
          id: string;
          unassigned_at: string | null;
          vehicle_id: string;
        };
        Insert: {
          assigned_at?: string;
          assigned_by?: string | null;
          driver_id: string;
          id?: string;
          unassigned_at?: string | null;
          vehicle_id: string;
        };
        Update: {
          assigned_at?: string;
          assigned_by?: string | null;
          driver_id?: string;
          id?: string;
          unassigned_at?: string | null;
          vehicle_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'driver_vehicle_assignments_assigned_by_fkey';
            columns: ['assigned_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'driver_vehicle_assignments_driver_id_fkey';
            columns: ['driver_id'];
            isOneToOne: false;
            referencedRelation: 'drivers';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'driver_vehicle_assignments_vehicle_id_fkey';
            columns: ['vehicle_id'];
            isOneToOne: false;
            referencedRelation: 'vehicles';
            referencedColumns: ['id'];
          },
        ];
      };
      drivers: {
        Row: {
          approval_status: Database['public']['Enums']['driver_approval_status'];
          approved_at: string | null;
          approved_by: string | null;
          created_at: string;
          id: string;
          is_available: boolean;
          rating_average: number;
          rating_count: number;
          updated_at: string;
        };
        Insert: {
          approval_status?: Database['public']['Enums']['driver_approval_status'];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          id: string;
          is_available?: boolean;
          rating_average?: number;
          rating_count?: number;
          updated_at?: string;
        };
        Update: {
          approval_status?: Database['public']['Enums']['driver_approval_status'];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          id?: string;
          is_available?: boolean;
          rating_average?: number;
          rating_count?: number;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'drivers_approved_by_fkey';
            columns: ['approved_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'drivers_id_fkey';
            columns: ['id'];
            isOneToOne: true;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      notifications: {
        Row: {
          body: string;
          created_at: string;
          data: Json;
          id: string;
          read_at: string | null;
          title: string;
          type: string;
          user_id: string;
        };
        Insert: {
          body: string;
          created_at?: string;
          data?: Json;
          id?: string;
          read_at?: string | null;
          title: string;
          type: string;
          user_id: string;
        };
        Update: {
          body?: string;
          created_at?: string;
          data?: Json;
          id?: string;
          read_at?: string | null;
          title?: string;
          type?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'notifications_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      places: {
        Row: {
          created_at: string;
          description: string | null;
          id: string;
          is_active: boolean;
          location: unknown;
          name: string;
          sort_order: number;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          description?: string | null;
          id?: string;
          is_active?: boolean;
          location: unknown;
          name: string;
          sort_order?: number;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          description?: string | null;
          id?: string;
          is_active?: boolean;
          location?: unknown;
          name?: string;
          sort_order?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      profiles: {
        Row: {
          avatar_path: string | null;
          created_at: string;
          full_name: string;
          id: string;
          phone: string | null;
          push_token: string | null;
          role: Database['public']['Enums']['user_role'];
          status: Database['public']['Enums']['user_status'];
          updated_at: string;
        };
        Insert: {
          avatar_path?: string | null;
          created_at?: string;
          full_name: string;
          id: string;
          phone?: string | null;
          push_token?: string | null;
          role?: Database['public']['Enums']['user_role'];
          status?: Database['public']['Enums']['user_status'];
          updated_at?: string;
        };
        Update: {
          avatar_path?: string | null;
          created_at?: string;
          full_name?: string;
          id?: string;
          phone?: string | null;
          push_token?: string | null;
          role?: Database['public']['Enums']['user_role'];
          status?: Database['public']['Enums']['user_status'];
          updated_at?: string;
        };
        Relationships: [];
      };
      ratings: {
        Row: {
          comment: string | null;
          created_at: string;
          id: string;
          rated_id: string;
          rater_id: string;
          ride_id: string;
          stars: number;
        };
        Insert: {
          comment?: string | null;
          created_at?: string;
          id?: string;
          rated_id: string;
          rater_id: string;
          ride_id: string;
          stars: number;
        };
        Update: {
          comment?: string | null;
          created_at?: string;
          id?: string;
          rated_id?: string;
          rater_id?: string;
          ride_id?: string;
          stars?: number;
        };
        Relationships: [
          {
            foreignKeyName: 'ratings_rated_id_fkey';
            columns: ['rated_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'ratings_rater_id_fkey';
            columns: ['rater_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'ratings_ride_id_fkey';
            columns: ['ride_id'];
            isOneToOne: false;
            referencedRelation: 'rides';
            referencedColumns: ['id'];
          },
        ];
      };
      reports: {
        Row: {
          category: string;
          created_at: string;
          description: string;
          id: string;
          reporter_id: string;
          resolution_notes: string | null;
          resolved_at: string | null;
          resolved_by: string | null;
          ride_id: string | null;
          status: Database['public']['Enums']['report_status'];
          updated_at: string;
        };
        Insert: {
          category: string;
          created_at?: string;
          description: string;
          id?: string;
          reporter_id: string;
          resolution_notes?: string | null;
          resolved_at?: string | null;
          resolved_by?: string | null;
          ride_id?: string | null;
          status?: Database['public']['Enums']['report_status'];
          updated_at?: string;
        };
        Update: {
          category?: string;
          created_at?: string;
          description?: string;
          id?: string;
          reporter_id?: string;
          resolution_notes?: string | null;
          resolved_at?: string | null;
          resolved_by?: string | null;
          ride_id?: string | null;
          status?: Database['public']['Enums']['report_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'reports_reporter_id_fkey';
            columns: ['reporter_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'reports_resolved_by_fkey';
            columns: ['resolved_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'reports_ride_id_fkey';
            columns: ['ride_id'];
            isOneToOne: false;
            referencedRelation: 'rides';
            referencedColumns: ['id'];
          },
        ];
      };
      ride_locations: {
        Row: {
          accuracy_m: number | null;
          id: number;
          location: unknown;
          recorded_at: string;
          ride_id: string;
          speed_kmh: number | null;
        };
        Insert: {
          accuracy_m?: number | null;
          id?: never;
          location: unknown;
          recorded_at?: string;
          ride_id: string;
          speed_kmh?: number | null;
        };
        Update: {
          accuracy_m?: number | null;
          id?: never;
          location?: unknown;
          recorded_at?: string;
          ride_id?: string;
          speed_kmh?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: 'ride_locations_ride_id_fkey';
            columns: ['ride_id'];
            isOneToOne: false;
            referencedRelation: 'rides';
            referencedColumns: ['id'];
          },
        ];
      };
      ride_offers: {
        Row: {
          distance_m: number | null;
          driver_id: string;
          expires_at: string;
          id: string;
          offered_at: string;
          request_id: string;
          responded_at: string | null;
          response: Database['public']['Enums']['ride_offer_response'];
        };
        Insert: {
          distance_m?: number | null;
          driver_id: string;
          expires_at: string;
          id?: string;
          offered_at?: string;
          request_id: string;
          responded_at?: string | null;
          response?: Database['public']['Enums']['ride_offer_response'];
        };
        Update: {
          distance_m?: number | null;
          driver_id?: string;
          expires_at?: string;
          id?: string;
          offered_at?: string;
          request_id?: string;
          responded_at?: string | null;
          response?: Database['public']['Enums']['ride_offer_response'];
        };
        Relationships: [
          {
            foreignKeyName: 'ride_offers_driver_id_fkey';
            columns: ['driver_id'];
            isOneToOne: false;
            referencedRelation: 'drivers';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'ride_offers_request_id_fkey';
            columns: ['request_id'];
            isOneToOne: false;
            referencedRelation: 'ride_requests';
            referencedColumns: ['id'];
          },
        ];
      };
      ride_requests: {
        Row: {
          assigned_at: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          cancelled_by: Database['public']['Enums']['actor_type'] | null;
          completed_at: string | null;
          contact_phone: string;
          created_at: string;
          destination: unknown;
          destination_label: string;
          destination_place_id: string | null;
          expires_at: string;
          id: string;
          origin: unknown;
          origin_label: string;
          origin_place_id: string | null;
          passenger_count: number;
          passenger_id: string;
          pickup_reference: string | null;
          requested_at: string;
          started_at: string | null;
          status: Database['public']['Enums']['ride_request_status'];
          updated_at: string;
        };
        Insert: {
          assigned_at?: string | null;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: Database['public']['Enums']['actor_type'] | null;
          completed_at?: string | null;
          contact_phone: string;
          created_at?: string;
          destination: unknown;
          destination_label: string;
          destination_place_id?: string | null;
          expires_at: string;
          id?: string;
          origin: unknown;
          origin_label: string;
          origin_place_id?: string | null;
          passenger_count: number;
          passenger_id: string;
          pickup_reference?: string | null;
          requested_at?: string;
          started_at?: string | null;
          status?: Database['public']['Enums']['ride_request_status'];
          updated_at?: string;
        };
        Update: {
          assigned_at?: string | null;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: Database['public']['Enums']['actor_type'] | null;
          completed_at?: string | null;
          contact_phone?: string;
          created_at?: string;
          destination?: unknown;
          destination_label?: string;
          destination_place_id?: string | null;
          expires_at?: string;
          id?: string;
          origin?: unknown;
          origin_label?: string;
          origin_place_id?: string | null;
          passenger_count?: number;
          passenger_id?: string;
          pickup_reference?: string | null;
          requested_at?: string;
          started_at?: string | null;
          status?: Database['public']['Enums']['ride_request_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'ride_requests_destination_place_id_fkey';
            columns: ['destination_place_id'];
            isOneToOne: false;
            referencedRelation: 'places';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'ride_requests_origin_place_id_fkey';
            columns: ['origin_place_id'];
            isOneToOne: false;
            referencedRelation: 'places';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'ride_requests_passenger_id_fkey';
            columns: ['passenger_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      rides: {
        Row: {
          accepted_at: string;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          cancelled_by: Database['public']['Enums']['actor_type'] | null;
          completed_at: string | null;
          created_at: string;
          distance_m: number | null;
          driver_arrived_at: string | null;
          driver_id: string;
          duration_s: number | null;
          id: string;
          passenger_count: number;
          request_id: string;
          started_at: string | null;
          status: Database['public']['Enums']['ride_status'];
          updated_at: string;
          vehicle_id: string;
        };
        Insert: {
          accepted_at?: string;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: Database['public']['Enums']['actor_type'] | null;
          completed_at?: string | null;
          created_at?: string;
          distance_m?: number | null;
          driver_arrived_at?: string | null;
          driver_id: string;
          duration_s?: number | null;
          id?: string;
          passenger_count: number;
          request_id: string;
          started_at?: string | null;
          status?: Database['public']['Enums']['ride_status'];
          updated_at?: string;
          vehicle_id: string;
        };
        Update: {
          accepted_at?: string;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: Database['public']['Enums']['actor_type'] | null;
          completed_at?: string | null;
          created_at?: string;
          distance_m?: number | null;
          driver_arrived_at?: string | null;
          driver_id?: string;
          duration_s?: number | null;
          id?: string;
          passenger_count?: number;
          request_id?: string;
          started_at?: string | null;
          status?: Database['public']['Enums']['ride_status'];
          updated_at?: string;
          vehicle_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'rides_driver_id_fkey';
            columns: ['driver_id'];
            isOneToOne: false;
            referencedRelation: 'drivers';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'rides_request_id_fkey';
            columns: ['request_id'];
            isOneToOne: false;
            referencedRelation: 'ride_requests';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'rides_vehicle_id_fkey';
            columns: ['vehicle_id'];
            isOneToOne: false;
            referencedRelation: 'vehicles';
            referencedColumns: ['id'];
          },
        ];
      };
      service_area: {
        Row: {
          boundary: unknown;
          id: boolean;
          name: string;
          source: string;
          updated_at: string;
        };
        Insert: {
          boundary: unknown;
          id?: boolean;
          name: string;
          source: string;
          updated_at?: string;
        };
        Update: {
          boundary?: unknown;
          id?: boolean;
          name?: string;
          source?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      vehicles: {
        Row: {
          created_at: string;
          id: string;
          max_passengers: number;
          model: string | null;
          notes: string | null;
          plate: string;
          status: Database['public']['Enums']['vehicle_status'];
          unit_number: number;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          max_passengers: number;
          model?: string | null;
          notes?: string | null;
          plate: string;
          status?: Database['public']['Enums']['vehicle_status'];
          unit_number: number;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          max_passengers?: number;
          model?: string | null;
          notes?: string | null;
          plate?: string;
          status?: Database['public']['Enums']['vehicle_status'];
          unit_number?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      accept_ride_offer: { Args: { p_offer_id: string }; Returns: string };
      assert_ride_driver: {
        Args: {
          p_allowed: Database['public']['Enums']['ride_status'][];
          p_ride_id: string;
        };
        Returns: {
          accepted_at: string;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          cancelled_by: Database['public']['Enums']['actor_type'] | null;
          completed_at: string | null;
          created_at: string;
          distance_m: number | null;
          driver_arrived_at: string | null;
          driver_id: string;
          duration_s: number | null;
          id: string;
          passenger_count: number;
          request_id: string;
          started_at: string | null;
          status: Database['public']['Enums']['ride_status'];
          updated_at: string;
          vehicle_id: string;
        };
        SetofOptions: {
          from: '*';
          to: 'rides';
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      auth_role: {
        Args: never;
        Returns: Database['public']['Enums']['user_role'];
      };
      cancel_request: {
        Args: { p_reason?: string; p_request_id: string };
        Returns: undefined;
      };
      cancel_ride: {
        Args: { p_reason?: string; p_ride_id: string };
        Returns: undefined;
      };
      complete_ride: { Args: { p_ride_id: string }; Returns: undefined };
      confirm_driver_arrival: {
        Args: { p_ride_id: string };
        Returns: undefined;
      };
      driver_linked_to_request: {
        Args: { p_request_id: string };
        Returns: boolean;
      };
      expire_stale_requests: { Args: never; Returns: number };
      find_available_drivers: {
        Args: {
          p_max_staleness?: string;
          p_origin: unknown;
          p_passenger_count: number;
        };
        Returns: {
          distance_m: number;
          driver_id: string;
          full_name: string;
          max_passengers: number;
          plate: string;
          rating_average: number;
          unit_number: number;
        }[];
      };
      get_active_request: {
        Args: never;
        Returns: {
          destination_label: string;
          destination_lat: number;
          destination_lng: number;
          driver_id: string;
          driver_name: string;
          driver_phone: string;
          driver_rating: number;
          expires_at: string;
          id: string;
          origin_label: string;
          origin_lat: number;
          origin_lng: number;
          passenger_count: number;
          pickup_reference: string;
          requested_at: string;
          ride_id: string;
          ride_status: Database['public']['Enums']['ride_status'];
          seconds_remaining: number;
          status: Database['public']['Enums']['ride_request_status'];
          vehicle_plate: string;
          vehicle_unit_number: number;
        }[];
      };
      get_driver_cancelled_notice: {
        Args: never;
        Returns: {
          cancelled_at: string;
          destination_label: string;
          driver_name: string;
          id: string;
          origin_label: string;
        }[];
      };
      get_driver_job: {
        Args: { p_offer_id: string };
        Returns: {
          accepted_at: string;
          cancellation_reason: string;
          cancelled_at: string;
          cancelled_by: Database['public']['Enums']['actor_type'];
          completed_at: string;
          destination_label: string;
          distance_m: number;
          driver_arrived_at: string;
          duration_s: number;
          my_comment: string;
          my_stars: number;
          offer_expires_at: string;
          offer_id: string;
          offered_at: string;
          origin_label: string;
          outcome: string;
          passenger_count: number;
          passenger_name: string;
          pickup_distance_m: number;
          pickup_reference: string;
          request_id: string;
          requested_at: string;
          responded_at: string;
          ride_id: string;
          started_at: string;
        }[];
      };
      get_driver_location: {
        Args: { p_driver_id: string };
        Returns: {
          age_seconds: number;
          heading: number;
          latitude: number;
          longitude: number;
          updated_at: string;
        }[];
      };
      get_finished_request: {
        Args: never;
        Returns: {
          already_rated: boolean;
          completed_at: string;
          destination_label: string;
          distance_m: number;
          driver_name: string;
          duration_s: number;
          id: string;
          origin_label: string;
          passenger_count: number;
          ride_id: string;
          vehicle_unit_number: number;
        }[];
      };
      get_passenger_trip: {
        Args: { p_request_id: string };
        Returns: {
          accepted_at: string;
          cancellation_reason: string;
          cancelled_at: string;
          cancelled_by: Database['public']['Enums']['actor_type'];
          completed_at: string;
          destination_label: string;
          distance_m: number;
          driver_arrived_at: string;
          driver_name: string;
          duration_s: number;
          expires_at: string;
          my_comment: string;
          my_stars: number;
          origin_label: string;
          passenger_count: number;
          pickup_reference: string;
          request_id: string;
          requested_at: string;
          ride_id: string;
          ride_status: Database['public']['Enums']['ride_status'];
          started_at: string;
          status: Database['public']['Enums']['ride_request_status'];
          vehicle_plate: string;
          vehicle_unit_number: number;
        }[];
      };
      get_setting: { Args: { p_default?: Json; p_key: string }; Returns: Json };
      has_active_ride_with_driver: {
        Args: { p_driver_id: string };
        Returns: boolean;
      };
      is_active_driver_of_ride: {
        Args: { p_ride_id: string };
        Returns: boolean;
      };
      is_admin: { Args: never; Returns: boolean };
      is_within_service_area: {
        Args: { p_lat: number; p_lng: number };
        Returns: boolean;
      };
      list_driver_active_rides: {
        Args: never;
        Returns: {
          accepted_at: string;
          destination_label: string;
          destination_lat: number;
          destination_lng: number;
          origin_label: string;
          origin_lat: number;
          origin_lng: number;
          passenger_count: number;
          passenger_name: string;
          passenger_phone: string;
          pickup_reference: string;
          request_id: string;
          ride_id: string;
          status: Database['public']['Enums']['ride_status'];
        }[];
      };
      list_driver_history: {
        Args: { p_limit?: number; p_offset?: number };
        Returns: {
          already_rated: boolean;
          cancelled_by: Database['public']['Enums']['actor_type'];
          destination_label: string;
          distance_m: number;
          duration_s: number;
          finished_at: string;
          offer_id: string;
          offered_at: string;
          origin_label: string;
          outcome: string;
          passenger_count: number;
          passenger_name: string;
          pickup_distance_m: number;
          request_id: string;
          responded_at: string;
          ride_id: string;
        }[];
      };
      list_driver_offers: {
        Args: never;
        Returns: {
          destination_label: string;
          destination_lat: number;
          destination_lng: number;
          distance_m: number;
          expires_at: string;
          offer_id: string;
          origin_label: string;
          origin_lat: number;
          origin_lng: number;
          passenger_count: number;
          request_id: string;
          requested_at: string;
          seconds_remaining: number;
        }[];
      };
      list_passenger_history: {
        Args: { p_limit?: number; p_offset?: number };
        Returns: {
          already_rated: boolean;
          cancellation_reason: string;
          cancelled_by: Database['public']['Enums']['actor_type'];
          destination_label: string;
          distance_m: number;
          driver_name: string;
          duration_s: number;
          finished_at: string;
          origin_label: string;
          passenger_count: number;
          request_id: string;
          requested_at: string;
          ride_id: string;
          status: Database['public']['Enums']['ride_request_status'];
          vehicle_plate: string;
          vehicle_unit_number: number;
        }[];
      };
      list_places: {
        Args: never;
        Returns: {
          description: string;
          id: string;
          lat: number;
          lng: number;
          name: string;
        }[];
      };
      offer_pending_requests: { Args: never; Returns: number };
      offer_request_to_drivers: {
        Args: { p_limit?: number; p_request_id: string };
        Returns: number;
      };
      owns_request: { Args: { p_request_id: string }; Returns: boolean };
      participates_in_ride: { Args: { p_ride_id: string }; Returns: boolean };
      rate_ride: {
        Args: { p_comment?: string; p_ride_id: string; p_stars: number };
        Returns: string;
      };
      reject_ride_offer: { Args: { p_offer_id: string }; Returns: undefined };
      request_ride: {
        Args: {
          p_destination_label: string;
          p_destination_lat: number;
          p_destination_lng: number;
          p_destination_place_id?: string;
          p_origin_label: string;
          p_origin_lat: number;
          p_origin_lng: number;
          p_origin_place_id?: string;
          p_passenger_count: number;
          p_pickup_reference?: string;
        };
        Returns: string;
      };
      ride_offer_outcome: {
        Args: {
          p_request_status: Database['public']['Enums']['ride_request_status'];
          p_response: Database['public']['Enums']['ride_offer_response'];
          p_ride_status: Database['public']['Enums']['ride_status'];
        };
        Returns: string;
      };
      send_push_notification: {
        Args: {
          p_body: string;
          p_data?: Json;
          p_title: string;
          p_type: string;
          p_user_id: string;
        };
        Returns: undefined;
      };
      shares_ride_with: { Args: { p_other_id: string }; Returns: boolean };
      start_driving_to_pickup: {
        Args: { p_ride_id: string };
        Returns: undefined;
      };
      start_ride: { Args: { p_ride_id: string }; Returns: undefined };
    };
    Enums: {
      actor_type: 'passenger' | 'driver' | 'admin' | 'system';
      document_owner: 'driver' | 'vehicle';
      driver_approval_status: 'pending' | 'approved' | 'blocked';
      report_status: 'open' | 'in_review' | 'resolved';
      ride_offer_response: 'pending' | 'accepted' | 'rejected' | 'expired';
      ride_request_status:
        'searching' | 'assigned' | 'in_progress' | 'completed' | 'cancelled' | 'expired';
      ride_status:
        | 'assigned'
        | 'driver_on_the_way'
        | 'driver_arrived'
        | 'in_progress'
        | 'completed'
        | 'cancelled';
      user_role: 'passenger' | 'driver' | 'admin';
      user_status: 'active' | 'blocked';
      vehicle_status: 'active' | 'maintenance' | 'retired';
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, 'public'>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    ? (DefaultSchema['Tables'] & DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
    ? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema['CompositeTypes'] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
    ? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      actor_type: ['passenger', 'driver', 'admin', 'system'],
      document_owner: ['driver', 'vehicle'],
      driver_approval_status: ['pending', 'approved', 'blocked'],
      report_status: ['open', 'in_review', 'resolved'],
      ride_offer_response: ['pending', 'accepted', 'rejected', 'expired'],
      ride_request_status: [
        'searching',
        'assigned',
        'in_progress',
        'completed',
        'cancelled',
        'expired',
      ],
      ride_status: [
        'assigned',
        'driver_on_the_way',
        'driver_arrived',
        'in_progress',
        'completed',
        'cancelled',
      ],
      user_role: ['passenger', 'driver', 'admin'],
      user_status: ['active', 'blocked'],
      vehicle_status: ['active', 'maintenance', 'retired'],
    },
  },
} as const;
